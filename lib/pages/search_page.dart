import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../services/history_service.dart';
import '../services/quality_pref.dart';
import '../services/kugou_api/kugou_api_client.dart';
import '../services/kugou_api/kugou_models.dart';
import 'downloads_page.dart';
import 'player_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _api = KugouApiClient();
  List<KugouSongDetail> _results = const [];
  List<HotSearchBoard> _boards = const [];
  List<HistoryItem> _history = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadHistory();
    try {
      final boards = await _api.getHotSearch();
      if (mounted) setState(() => _boards = boards.take(3).toList());
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    final h = await HistoryService.instance.load();
    if (mounted) setState(() => _history = h);
  }

  Future<void> _search(String kw) async {
    if (kw.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _api.search(kw.trim());
      setState(() => _results = r?.songs ?? const []);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _play(KugouSongDetail d) async {
    final song = d.toSong();
    final player = context.read<PlayerProvider>();
    // 播放也走用户选的音质（与下载共用同一档偏好）。
    final quality = await QualityPref.instance.load();
    final url = await _api.getSongUrlWithFallback(
      d.hash,
      quality: quality,
      albumId: d.albumId,
      albumAudioId: d.albumAudioId,
    );
    if (url == null || url.url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('没拿到播放链接')));
      }
      return;
    }
    await player.playUrl(song, url.url, quality: url.quality);
    await HistoryService.instance.record(
      id: song.id,
      title: song.title,
      artist: song.artist,
      artworkUri: song.artworkUri,
    );
    await _loadHistory();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PlayerPage(song: song)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
        actions: [
          IconButton(
            tooltip: '已下载',
            icon: const Icon(Icons.download_done),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DownloadsPage()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_history.isNotEmpty) ...[
            Row(
              children: [
                const Text('最近播放',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await HistoryService.instance.clear();
                    await _loadHistory();
                  },
                  child: const Text('清空'),
                ),
              ],
            ),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _history.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final h = _history[i];
                  return ActionChip(
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(h.artist,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    onPressed: () => _controller.text = h.title,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '搜索歌曲、歌手',
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
              filled: true,
            ),
            onSubmitted: _search,
          ),
          const SizedBox(height: 16),
          if (_boards.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _boards
                  .expand((b) => b.keywords.take(6))
                  .map((k) => ActionChip(
                        label: Text(k),
                        onPressed: () {
                          _controller.text = k;
                          _search(k);
                        },
                      ))
                  .toList(),
            ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          ..._results.map(
            (d) => ListTile(
              leading: const Icon(Icons.music_note),
              title: Text(d.songName, maxLines: 1),
              subtitle: Text(d.artistName ?? '',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => _play(d),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
