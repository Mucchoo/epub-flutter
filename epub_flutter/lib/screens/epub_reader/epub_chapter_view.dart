import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../epub/models/epub_book.dart';
import '../../epub/models/epub_content_node.dart';
import '../../epub/styling/computed_style.dart';
import 'content_renderer.dart';

class EpubChapterView extends StatelessWidget {
  final EpubBook book;
  final List<EpubContentNode> nodes;
  final Map<int, ComputedStyle> styleMap;
  final int spineIndex;
  final void Function(String href, String? fragment) onLinkTap;
  final void Function(int spineIndex, List<NodeKey> keys)? onKeysReady;
  final double userFontSizeMultiplier;

  const EpubChapterView({
    super.key,
    required this.book,
    required this.nodes,
    required this.styleMap,
    required this.spineIndex,
    required this.onLinkTap,
    this.onKeysReady,
    this.userFontSizeMultiplier = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) return const SizedBox.shrink();

    final renderer = ContentRenderer(
      fileMap: book.fileMap,
      onLinkTap: onLinkTap,
      styleMap: styleMap,
      fontSizeMultiplier: userFontSizeMultiplier,
    );
    final result = renderer.renderWithKeys(nodes);

    if (onKeysReady != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        onKeysReady!(spineIndex, result.nodeKeys);
      });
    }

    return result.widget;
  }
}