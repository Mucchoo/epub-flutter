import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../epub/models/epub_book.dart';
import '../../epub/models/epub_content_node.dart';
import 'content_renderer.dart';

class EpubChapterView extends StatefulWidget {
  final EpubBook book;
  final int spineIndex;
  final void Function(String href, String? fragment) onLinkTap;
  final String? targetFragment;
  final void Function(int spineIndex, List<NodeKey> keys)? onKeysReady;

  const EpubChapterView({
    super.key,
    required this.book,
    required this.spineIndex,
    required this.onLinkTap,
    this.targetFragment,
    this.onKeysReady,
  });

  @override
  State<EpubChapterView> createState() => _EpubChapterViewState();
}

class _EpubChapterViewState extends State<EpubChapterView> {
  late Future<List<EpubContentNode>> _future;

  @override
  void initState() {
    super.initState();
    _future = Future(() => widget.book.getChapterContent(widget.spineIndex));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EpubContentNode>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final renderer = ContentRenderer(
          fileMap: widget.book.fileMap,
          onLinkTap: widget.onLinkTap,
        );
        final result = renderer.renderWithKeys(snapshot.data!);

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
