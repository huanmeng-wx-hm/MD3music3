import 'package:flutter/material.dart';

import '../widgets/apple_lyrics/models/lyric_line.dart';
import '../widgets/apple_lyrics/parsers/lyric_parser_chain.dart';

/// 逐行歌词。解析用抄来的 LyricParserChain（KRC/LRC/TTML 都认），
/// 渲染是新写的 ListView，不引那 19 个逐字动画零件。
class LyricView extends StatefulWidget {
  const LyricView({super.key, required this.text, required this.position});

  final String text;
  final Duration position;

  @override
  State<LyricView> createState() => _LyricViewState();
}

class _LyricViewState extends State<LyricView> {
  late List<LyricLine> _lines;
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _lines = LyricParserChain.parse(widget.text);
  }

  @override
  void didUpdateWidget(covariant LyricView old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _lines = LyricParserChain.parse(widget.text);
    }
  }

  int _active() {
    final ms = widget.position.inMilliseconds;
    var idx = 0;
    for (var i = 0; i < _lines.length; i++) {
      if (_lines[i].startTime <= ms) idx = i;
    }
    return idx;
  }

  @override
  Widget build(BuildContext context) {
    if (_lines.isEmpty) {
      return Center(child: Text(widget.text, textAlign: TextAlign.center));
    }
    final active = _active();
    return ListView.builder(
      controller: _controller,
      itemCount: _lines.length,
      padding: const EdgeInsets.symmetric(vertical: 60),
      itemBuilder: (_, i) {
        final l = _lines[i];
        final on = i == active;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Text(
            l.text.isEmpty ? '♪' : l.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: on ? 18 : 15,
              fontWeight: on ? FontWeight.w700 : FontWeight.w400,
              color: on
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withOpacity(.55),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
