import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/online_download_service.dart';
import '../data/models/song.dart';
import '../providers/player_provider.dart';
import '../services/kugou_api/kugou_api_client.dart';
import '../services/kugou_api/kugou_models.dart';
import '../services/quality_pref.dart';

/// 全屏播放器：返回 / 封面 / 歌名歌手 / 可拖进度 / 播放暂停 / 下载 / 音质。
///
/// 按老项目播放页的骨架重做，但砍掉歌词、推荐、评论、收藏与上下曲：
/// - 上下曲要新建播放队列、收藏要牵登录态与云端接口，按「牵动最少」不做。
/// - 底部用 SafeArea 吃掉系统导航栏(viewPadding.bottom)，三键导航/手势条
///   再出来也不会把进度条和控制键压住；小屏与横屏用 LayoutBuilder 缩放封面。
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.song});

  final Song song;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  static const _qualityOptions = <String, String>{
    KugouQuality.standard: '标准音质',
    KugouQuality.high: '高音质',
    KugouQuality.lossless: '无损音质',
    KugouQuality.hires: 'Hi-Res',
  };

  bool _downloading = false;
  bool _switching = false;
  double? _drag;

  String _fmt(Duration d) {
    final s = d.inSeconds < 0 ? 0 : d.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}'
        ':${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _pickQuality() async {
    final current = await QualityPref.instance.load();
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('音质（播放 / 下载共用）',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            ..._qualityOptions.entries.map(
              (e) => RadioListTile<String>(
                value: e.key,
                groupValue: current,
                title: Text(e.value),
                subtitle: Text(e.key, style: const TextStyle(fontSize: 11)),
                onChanged: (_) => Navigator.of(ctx).pop(e.key),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await _applyQuality(picked);
  }

  /// 换档后重新解析链接并续播当前位置；下载按钮也用这一档。
  Future<void> _applyQuality(String q) async {
    final p = context.read<PlayerProvider>();
    final song = p.currentSong ?? widget.song;
    final keep = p.position;
    setState(() => _switching = true);
    try {
      final url = await KugouApiClient().getSongUrlWithFallback(
        song.id,
        quality: q,
        albumId: song.albumId,
        albumAudioId: song.albumAudioId,
      );
      if (!mounted) return;
      if (url == null || url.url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没拿到该音质的链接')),
        );
        return;
      }
      await QualityPref.instance.save(q);
      // 显示服务端回写的实际音质，避免「选了 Hi-Res 其实掉到 128」的虚标。
      await p.playUrl(song, url.url, quality: url.quality, startAt: keep);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已切换：${KugouQuality.labelOf(url.quality)}')),
      );
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _download() async {
    final song = context.read<PlayerProvider>().currentSong ?? widget.song;
    setState(() => _downloading = true);
    try {
      final q = await QualityPref.instance.load();
      final path =
          await OnlineDownloadService.instance.downloadSong(song, q);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(path == null
              ? '下载失败'
              : '已下载（${KugouQuality.labelOf(q)}）'),
        ),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerProvider>();
    final song = p.currentSong ?? widget.song;
    final theme = Theme.of(context);

    final ratio = p.duration.inMilliseconds == 0
        ? 0.0
        : (p.position.inMilliseconds / p.duration.inMilliseconds)
            .clamp(0.0, 1.0);
    final shown = _drag ?? ratio;
    final shownPos = p.duration * shown;
    final remain = p.duration - shownPos;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              avatar: Icon(Icons.music_note,
                  size: 16, color: theme.colorScheme.primary),
              label: _switching
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(KugouQuality.labelOf(p.quality),
                      style: const TextStyle(fontSize: 12)),
              onPressed: _switching ? null : _pickQuality,
            ),
          ),
        ],
      ),
      // 关键：SafeArea 把系统状态栏 / 三键导航栏 / 手势条都留出来，
      // 底部控件不会再被黑条盖住。
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final art = math
                .min(c.maxWidth - 44, c.maxHeight * 0.42)
                .clamp(140.0, 340.0)
                .toDouble();
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      SizedBox(
                        width: art,
                        height: art,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: song.artworkUri == null
                              ? Container(
                                  color: theme
                                      .colorScheme.surfaceContainerHigh,
                                  child: const Icon(Icons.music_note, size: 72),
                                )
                              : Image.network(
                                  song.artworkUri!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: theme
                                        .colorScheme.surfaceContainerHigh,
                                    child:
                                        const Icon(Icons.music_note, size: 72),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Slider(
                        value: shown,
                        onChanged: (v) => setState(() => _drag = v),
                        onChangeEnd: (v) {
                          p.seek(p.duration * v);
                          setState(() => _drag = null);
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(shownPos),
                                style: theme.textTheme.bodySmall),
                            Text('-${_fmt(remain)}',
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: '下载',
                            iconSize: 30,
                            icon: _downloading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.download_outlined),
                            onPressed: _downloading ? null : _download,
                          ),
                          const SizedBox(width: 28),
                          IconButton(
                            iconSize: 60,
                            icon: Icon(
                              p.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              size: 60,
                            ),
                            onPressed: p.toggle,
                          ),
                          const SizedBox(width: 28),
                          IconButton(
                            tooltip: '音质',
                            iconSize: 30,
                            icon: const Icon(Icons.tune_outlined),
                            onPressed: _switching ? null : _pickQuality,
                          ),
                        ],
                      ),
                      if (p.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(p.error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 12)),
                        ),
                      // SafeArea 已吃掉 viewPadding.bottom，这里只补一点呼吸空间。
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
