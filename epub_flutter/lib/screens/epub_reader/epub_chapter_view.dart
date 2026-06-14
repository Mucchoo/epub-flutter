import 'package:flutter/material.dart';

import '../../epub/models/epub_book.dart';
import '../../epub/models/epub_content_node.dart';
import 'content_renderer.dart';

class EpubChapterView extends StatefulWidget {
  final EpubBook book;
  final int spineIndex;
  final void Function(String href, String? fragment) onLinkTap;
  final String? targetFragment;

  const EpubChapterView({
    super.key,
    required this.book,
    required this.spineIndex,
    required this.onLinkTap,
    this.targetFragment,
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
        return ContentRenderer(
          fileMap: widget.book.fileMap,
          onLinkTap: widget.onLinkTap,
        ).render(snapshot.data!);
      },
    );
  }
}
