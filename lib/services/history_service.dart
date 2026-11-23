import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 只存歌曲标识 + 展示信息 + 时间，不存播放链接（带时效）。
class HistoryItem {
  final String id;
  final String title;
  final String artist;
  final String? artworkUri;
  final DateTime playedAt;

  const HistoryItem({
    required this.id,
    required this.title,
    required this.artist,
    this.artworkUri,
    required this.playedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'artworkUri': artworkUri,
        'playedAt': playedAt.millisecondsSinceEpoch,
      };

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        artist: j['artist'] as String? ?? '',
        artworkUri: j['artworkUri'] as String?,
        playedAt: DateTime.fromMillisecondsSinceEpoch(
          j['playedAt'] as int? ?? 0,
        ),
      );
}

class HistoryService {
  HistoryService._();
  static final HistoryService instance = HistoryService._();
  static const _key = 'mini_history_v1';
  static const _max = 50;

  Future<List<HistoryItem>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(_key) ?? const [];
    return raw
        .map((e) => HistoryItem.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> record({
    required String id,
    required String title,
    required String artist,
    String? artworkUri,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_key) ?? <String>[];
    list.removeWhere((e) {
      try {
        return (jsonDecode(e) as Map)['id'] == id;
      } catch (_) {
        return false;
      }
    });
    list.insert(
      0,
      jsonEncode(HistoryItem(
        id: id,
        title: title,
        artist: artist,
        artworkUri: artworkUri,
        playedAt: DateTime.now(),
      ).toJson()),
    );
    if (list.length > _max) list.removeRange(_max, list.length);
    await sp.setStringList(_key, list);
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key);
  }
}
