import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/player_provider.dart';
import 'services/kugou_server.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
