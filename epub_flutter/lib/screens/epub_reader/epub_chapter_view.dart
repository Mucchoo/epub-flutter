import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../epub/models/epub_book.dart';
import '../../epub/models/epub_content_node.dart';
import '../../epub/styling/computed_style.dart';
import 'content_renderer.dart';
import 'epub_parser_isolate.dart';

typedef _ChapterData = ({
  List<EpubContentNode> nodes,
  Map<int, ComputedStyle> styleMap,
});

class EpubChapterView extends StatefulWidget {
  final EpubBook book;
  final int spineIndex;
  final void Function(String href, String? fragment) onLinkTap;
  final String? targetFragment;
  final void Function(int spineIndex, List<NodeKey> keys)? onKeysReady;
  final double userFontSizeMultiplier;
  final Map<String, List<int>> cssFileBytes;
  final Future<SendPort> isolateSendPort;

  const EpubChapterView({
    super.key,
    required this.book,
    required this.spineIndex,
    required this.onLinkTap,
    required this.cssFileBytes,
    required this.isolateSendPort,
    this.targetFragment,
    this.onKeysReady,
    this.userFontSizeMultiplier = 1.0,
  });

  @override
  State<EpubChapterView> createState() => _EpubChapterViewState();
}

class _EpubChapterViewState extends State<EpubChapterView> {
  late Future<_ChapterData> _future;

  @override
  void initState() {
    super.initState();
    _future = _buildChapter();
  }

  @override
  void didUpdateWidget(EpubChapterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userFontSizeMultiplier != widget.userFontSizeMultiplier) {
      setState(() {});
    }
  }

  Future<_ChapterData> _buildChapter() async {
    final spineItem = widget.book.spine[widget.spineIndex];
    final href = spineItem.manifestItem.href;
    final file = widget.book.fileMap[href];
    if (file == null) {
      return (nodes: <EpubContentNode>[], styleMap: <int, ComputedStyle>{});
    }

    final sendPort = await widget.isolateSendPort;
    final replyPort = ReceivePort();

    sendPort.send(ChapterParseRequest(
      replyTo: replyPort.sendPort,
      htmlBytes: file.content as List<int>,
      chapterHref: href,
      cssFileBytes: widget.cssFileBytes,
      knownFilePaths: widget.book.fileMap.keys.toSet(),
    ));

    final result = await replyPort.first as ChapterParseResult;
    replyPort.close();
    return (nodes: result.nodes, styleMap: result.styleMap);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ChapterData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data!.nodes.isEmpty) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;
        final renderer = ContentRenderer(
          fileMap: widget.book.fileMap,
          onLinkTap: widget.onLinkTap,
          styleMap: data.styleMap,
          fontSizeMultiplier: widget.userFontSizeMultiplier,
        );
        final result = renderer.renderWithKeys(data.nodes);

        if (widget.onKeysReady != null) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onKeysReady!(widget.spineIndex, result.nodeKeys);
            }
          });
        }

        return result.widget;
      },
    );
  }
}
