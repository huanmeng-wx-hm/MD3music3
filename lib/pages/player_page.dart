import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/online_download_service.dart';
import '../data/models/song.dart';
import '../providers/player_provider.dart';
import '../services/kugou_api/kugou_api_client.dart';
import '../services/kugou_api/kugou_models.dart';
import '../widgets/lyric_view.dart';

/// 全屏播放器：封面 / 进度 / 播放键 / 逐行歌词 / 下载按钮。
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.song});

  final Song song;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  String? _lyric;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _loadLyric();
  }

  Future<void> _loadLyric() async {
    try {
      final l = await KugouApiClient().getLyric(
        widget.song.id,
        songName: widget.song.title,
        fmt: 'lrc',
        decode: true,
      );
      if (mounted) {
        setState(() => _lyric = (l?.decodedContent ?? l?.content ?? '').trim());
      }
    } catch (_) {}
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final path = await OnlineDownloadService()
          .downloadSong(widget.song, KugouQuality.standard);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(path == null ? '下载失败' : '已下载到：$path')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerProvider>();
    final song = p.currentSong ?? widget.song;
    return Scaffold(
      appBar: AppBar(title: Text(song.title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: song.artworkUri == null
                    ? Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHigh,
                        child: const Icon(Icons.music_note, size: 72),
                      )
                    : Image.network(song.artworkUri!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.music_note, size: 72)),
              ),
            ),
            const SizedBox(height: 16),
            Text(song.title,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(song.artist, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Expanded(
              child: _lyric == null || _lyric!.isEmpty
                  ? const Center(child: Text('暂无歌词'))
                  : LyricView(text: _lyric!, position: p.position),
            ),
            Slider(
              value: p.duration.inMilliseconds == 0
                  ? 0
                  : (p.position.inMilliseconds / p.duration.inMilliseconds)
                      .clamp(0.0, 1.0),
              onChanged: (v) => p.seek(p.duration * v),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '下载',
                  icon: _downloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download),
                  onPressed: _downloading ? null : _download,
                ),
                const SizedBox(width: 24),
                IconButton(
                  iconSize: 48,
                  icon: Icon(p.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled),
                  onPressed: p.toggle,
                ),
              ],
            ),
            if (p.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(p.error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
