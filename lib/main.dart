import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/player_provider.dart';
import 'services/kugou_server.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 后台播放 / 系统媒体通知。必须在任何 AudioPlayer 创建之前初始化。
  // just_audio_background 内部就是 audio_service，默认通知带
  // 播放/暂停 + 可拖动的进度（MediaAction.seek）。
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.huanmengwxhm.md3music3.audio',
      androidNotificationChannelName: '播放',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    );
  } catch (e) {
    debugPrint('[mini] background audio init failed: $e');
  }

  try {
    await KugouApiServer.start();
  } catch (e) {
    debugPrint('[mini] kugou server start failed: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => PlayerProvider(),
      child: const MiniApp(),
    ),
  );
}
