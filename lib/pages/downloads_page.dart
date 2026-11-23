import 'dart:io';

import 'package:flutter/material.dart';

import '../core/services/online_download_service.dart';

/// A2 的独立「已下载」页：直接列下载目录里的音频文件。
class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  List<File> _files = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dir = Directory(await OnlineDownloadService.downloadDirPath());
      final list = dir.existsSync()
          ? dir
              .listSync()
              .whereType<File>()
              .where((f) => RegExp(
                      r'\.(mp3|m4a|flac|ogg|wav|aac)$',
                      caseSensitive: false)
                  .hasMatch(f.path))
              .toList()
          : <File>[];
      if (mounted) setState(() => _files = list);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('已下载'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : _files.isEmpty
              ? const Center(child: Text('还没有下载歌曲'))
              : ListView.separated(
                  itemCount: _files.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => ListTile(
                    leading: const Icon(Icons.audiotrack),
                    title: Text(_files[i].uri.pathSegments.last),
                    subtitle: Text(
                        '${(_files[i].lengthSync() / 1048576).toStringAsFixed(1)} MB'),
                  ),
                ),
    );
  }
}
