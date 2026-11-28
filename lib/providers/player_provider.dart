import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../data/models/song.dart';
import '../services/kugou_api/kugou_models.dart';
import '../services/sign_in_service.dart';

/// 极简播放状态，兼作抄来的 online_download_service.dart 的 shim。
class PlayerProvider extends ChangeNotifier {
  PlayerProvider() {
    _player.positionStream.listen((p) {
      _position = p;
      notifyListeners();
    });
    _player.durationStream.listen((d) {
      _duration = d ?? Duration.zero;
      notifyListeners();
    });
    _player.playingStream.listen((v) {
      _isPlaying = v;
      notifyListeners();
    });
  }

  final AudioPlayer _player = AudioPlayer();

  // online_download_service.install() 会挂这两个钩子，不能删。
  static Future<String?> Function(String id, String quality)?
      resolveLocalAudioPath;
  static void Function(Song song, String quality, String url)?
      onPlaybackSourceStarted;

  Song? _current;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _error;
  String _quality = KugouQuality.standard;

  Song? get currentSong => _current;
  bool get isPlaying => _isPlaying;
  bool get isPlaybackNotReady => _current != null && _error != null;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get error => _error;

  /// 当前「实际」音质（服务端回写，可能与请求档不同，用于不虚标）。
  String get quality => _quality;

  /// 在线播放：拿链接直接喂，不落盘。
  /// [quality] 传 KugouPlayUrl.quality（实际档），[startAt] 用于切音质后续播。
  Future<void> playUrl(
    Song song,
    String url, {
    String quality = KugouQuality.standard,
    Duration startAt = Duration.zero,
  }) async {
    _current = song;
    _error = null;
    _quality = quality;
    notifyListeners();
    onPlaybackSourceStarted?.call(song, quality, url);

    // 播放歌曲时自动签到：不阻塞 setUrl/play；Service 内部按「当天一次」
    // 去重，未登录静默跳过，切音质续播也不会重复发请求。
    unawaited(SignInService.instance.autoSignIfNeeded());

    // tag 挂 MediaItem，just_audio_background 才能出通知栏 / 锁屏 / 线控，
    // 且默认带 MediaAction.seek，通知上的进度条可直接拖。
    final item = MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album.isEmpty ? null : song.album,
      duration: song.duration == Duration.zero ? null : song.duration,
      artUri: song.artworkUri == null ? null : Uri.tryParse(song.artworkUri!),
    );

    try {
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(url), tag: item),
      );
      if (startAt > Duration.zero) {
        await _player.seek(startAt);
      }
      await _player.play();
    } catch (e) {
      _error = '$e';
      notifyListeners();
    }
  }

  Future<void> toggle() async =>
      _isPlaying ? _player.pause() : _player.play();
  Future<void> seek(Duration d) => _player.seek(d);

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
