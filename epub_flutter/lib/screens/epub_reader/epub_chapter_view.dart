import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:html/dom.dart' as dom;

import '../../epub/models/epub_book.dart';
import '../../epub/models/epub_content_node.dart';
import '../../epub/parser/content_parser.dart';
import '../../epub/styling/computed_style.dart';
import '../../epub/styling/css_cascade.dart';
import '../../epub/styling/css_parser.dart';
import '../../epub/styling/font_loader_service.dart';
import 'content_renderer.dart';

typedef _ChapterData = ({
  List<EpubContentNode> nodes,
  ComputedStyleMap styleMap,
});

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
  late Future<_ChapterData> _future;

  @override
  void initState() {
    super.initState();
    _future = _buildChapter();
  }

  Future<_ChapterData> _buildChapter() async {
    final spineItem = widget.book.spine[widget.spineIndex];
    final file = widget.book.fileMap[spineItem.manifestItem.href];
    if (file == null) {
      return (nodes: <EpubContentNode>[], styleMap: <dom.Element, ComputedStyle>{});
    }

    final bytes = file.content as List<int>;
    final parser = ContentParser(
      chapterHref: spineItem.manifestItem.href,
      fileMap: widget.book.fileMap,
    );
    final nodes = parser.parse(bytes);

    // Collect CSS rules in source order (linked → embedded)
    final allRules = <CssRule>[];
    final fontLoader = FontLoaderService(
      fileMap: widget.book.fileMap,
      opfDir: widget.book.opfDir,
    );

    for (final cssPath in parser.linkedStylesheetPaths) {
      final cssFile = widget.book.fileMap[cssPath];
      if (cssFile == null) continue;
      final cssText = utf8.decode(cssFile.content as List<int>);
      allRules.addAll(CssParser.parse(cssText, sourceHref: cssPath));
      await fontLoader.loadFontsFromStylesheet(cssText, cssPath);
    }

    for (final cssText in parser.embeddedStyleTexts) {
      allRules.addAll(CssParser.parse(cssText));
    }

    // Build cascade engine and resolve styles for every DOM element
    final cascade = CssCascade(allRules);
    final styleMap = <dom.Element, ComputedStyle>{};
    _walkNodes(nodes, cascade, styleMap);

    return (nodes: nodes, styleMap: styleMap);
  }

  void _walkNodes(
    List<EpubContentNode> nodes,
    CssCascade cascade,
    ComputedStyleMap styleMap,
  ) {
    for (final node in nodes) {
      if (node.domElement != null) {
        styleMap[node.domElement!] = cascade.resolve(node.domElement!);
      }
      switch (node) {
        case EpubParagraphNode n:
          _walkNodes(n.children, cascade, styleMap);
        case EpubHeadingNode n:
          _walkNodes(n.children, cascade, styleMap);
        case EpubListNode n:
          for (final item in n.items) {
            _walkNodes(item.children, cascade, styleMap);
          }
        case EpubBlockquoteNode n:
          _walkNodes(n.children, cascade, styleMap);
        case EpubAnchorNode n:
          if (n.child != null) _walkNodes([n.child!], cascade, styleMap);
        default:
          break;
      }
    }
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
          baseFontSize: 16.0,
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
