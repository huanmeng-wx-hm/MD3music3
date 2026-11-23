import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models/song.dart';

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

  static Future<String?> Function(String id, String quality)?
      resolveLocalAudioPath;
  static void Function(Song song, String quality, String url)?
      onPlaybackSourceStarted;

  Song? _current;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _error;

  Song? get currentSong => _current;
  bool get isPlaying => _isPlaying;
  bool get isPlaybackNotReady => _current != null && _error != null;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get error => _error;

  /// 在线播放：拿链接直接喂，不落盘。
  Future<void> playUrl(Song song, String url, {String quality = '128'}) async {
    _current = song;
    _error = null;
    notifyListeners();
    onPlaybackSourceStarted?.call(song, quality, url);
    try {
      await _player.setUrl(url);
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
