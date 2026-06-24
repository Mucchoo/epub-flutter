import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../epub/models/epub_content_node.dart';
import '../../epub/styling/computed_style.dart';
import '../../epub/styling/style_applicator.dart';
import '../../theme/app_colors.dart';
import '../settings/reading_settings_notifier.dart';
import 'ai_chat/ai_chat_bottom_sheet.dart';
import 'reader_action.dart';
import 'reader_view_model.dart';

class EpubReaderScreen extends StatefulWidget {
  const EpubReaderScreen({
    super.key,
    required this.filePath,
    required this.bookId,
  });

  final String filePath;
  final int bookId;

  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen> {
  late final EpubReaderViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = EpubReaderViewModel(
      bookId: widget.bookId,
      filePath: widget.filePath,
    );
    _viewModel.loadBook();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final state = _viewModel.state;
        final fontSizeMultiplier = ReadingSettingsScope.of(
          context,
        ).fontSizeMultiplier;

        return Scaffold(
          backgroundColor: appBg,
          appBar: _appBar(
            state.book?.metadata.title ?? 'Book',
            overflow: TextOverflow.ellipsis,
          ),
          body: Stack(
            children: [
              SelectionArea(
                onSelectionChanged: (content) {
                  _viewModel.onAction(
                    SelectionUpdated(content?.plainText.trim() ?? ''),
                  );
                },
                contextMenuBuilder: (context, selectableRegionState) {
                  final matchedHighlight = _viewModel.pendingHighlightMatch;
                  final longEnough = _viewModel.selectionIsLongEnough;
                  return AdaptiveTextSelectionToolbar.buttonItems(
                    anchors: selectableRegionState.contextMenuAnchors,
                    buttonItems: [
                      ContextMenuButtonItem(
                        label: 'Ask AI',
                        onPressed: () {
                          final selectedText = _viewModel.pendingSelection;
                          _viewModel.onAction(AskAIButtonTapped());
                          ContextMenuController.removeAny();
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) =>
                                AiChatBottomSheet(selectedText: selectedText),
                          );
                        },
                      ),
                      if (longEnough && matchedHighlight != null)
                        ContextMenuButtonItem(
                          label: 'Delete highlight',
                          onPressed: () {
                            _viewModel.onAction(
                              DeleteHighlightButtonTapped(matchedHighlight.id!),
                            );
                            selectableRegionState.clearSelection();
                            ContextMenuController.removeAny();
                          },
                        )
                      else if (longEnough)
                        ContextMenuButtonItem(
                          label: 'Highlight',
                          onPressed: () {
                            _viewModel.onAction(HighlightButtonTapped());
                            selectableRegionState.clearSelection();
                            ContextMenuController.removeAny();
                          },
                        ),
                      ContextMenuButtonItem(
                        label: 'Copy',
                        onPressed: () {
                          _viewModel.onAction(CopyButtonTapped());
                          selectableRegionState.copySelection(
                            SelectionChangedCause.toolbar,
                          );
                          ContextMenuController.removeAny();
                        },
                      ),
                    ],
                  );
                },
                child: ListView.builder(
                  controller: _viewModel.scrollController,
                  itemCount: state.chapters.length,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  itemBuilder: (context, index) {
                    final data = state.chapterData[index];
                    if (data == null || data.nodes.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final chapterOffsets = _viewModel.chapterCharOffsets;
                    final totalChars = _viewModel.totalChars;
                    final chapterStart = chapterOffsets[index];
                    final chapterEnd = index + 1 < chapterOffsets.length
                        ? chapterOffsets[index + 1]
                        : totalChars;

                    final chapterHighlightRanges = <(int, int)>[];
                    for (final h in state.highlights) {
                      if (h.startOffset >= chapterEnd ||
                          h.endOffset <= chapterStart) continue;
                      final start = (h.startOffset - chapterStart)
                          .clamp(0, chapterEnd - chapterStart);
                      final end = (h.endOffset - chapterStart)
                          .clamp(0, chapterEnd - chapterStart);
                      chapterHighlightRanges.add((start, end));
                    }

                    return KeyedSubtree(
                      key: _viewModel.chapterKeys[index],
                      child: _renderNodes(
                        data.nodes,
                        data.styleMap,
                        fontSizeMultiplier,
                        chapterHighlightRanges,
                      ),
                    );
                  },
                ),
              ),
              if (state.isRestoring)
                const Positioned.fill(
                  child: ColoredBox(
                    color: appBg,
                    child: Center(
                      child: CircularProgressIndicator(color: appTextDark),
                    ),
                  ),
                ),
              if (!state.isRestoring)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(state.progressPercentage * 100).round()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              if (state.error != null)
                Scaffold(
                  backgroundColor: appBg,
                  appBar: _appBar('Error'),
                  body: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  AppBar _appBar(String title, {TextOverflow? overflow}) {
    return AppBar(
      backgroundColor: appBg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      foregroundColor: appTextDark,
      iconTheme: const IconThemeData(color: appTextDark),
      title: Text(
        title,
        overflow: overflow,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: appTextDark,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _renderNodes(
    List<EpubContentNode> nodes,
    Map<int, ComputedStyle> styleMap,
    double fontSizeMultiplier,
    List<(int, int)> highlightRanges, [
    int charOffset = 0,
  ]) {
    final children = <Widget>[];
    int offset = charOffset;
    for (final n in nodes) {
      final w = _renderNode(n, styleMap, fontSizeMultiplier, highlightRanges, offset);
      if (w != null) children.add(w);
      offset += n.extractText().length;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget? _renderNode(
    EpubContentNode node,
    Map<int, ComputedStyle> styleMap,
    double fontSizeMultiplier,
    List<(int, int)> highlightRanges,
    int charOffset,
  ) => switch (node) {
    EpubParagraphNode n => _renderParagraph(
      n,
      styleMap,
      fontSizeMultiplier,
      highlightRanges,
      charOffset,
    ),
    EpubHeadingNode n => _renderHeading(
      n,
      styleMap,
      fontSizeMultiplier,
      highlightRanges,
      charOffset,
    ),
    EpubImageNode n => _renderImage(n),
    EpubInlineImageNode n => _renderInlineImage(n),
    EpubListNode n => _renderList(
      n,
      styleMap,
      fontSizeMultiplier,
      highlightRanges,
      charOffset,
    ),
    EpubBlockquoteNode n => _renderBlockquote(
      n,
      styleMap,
      fontSizeMultiplier,
      highlightRanges,
      charOffset,
    ),
    EpubLineBreakNode _ => const SizedBox(height: 8),
    EpubDividerNode _ => const Divider(),
    EpubTextNode n => _renderParagraph(
      EpubParagraphNode([n]),
      styleMap,
      fontSizeMultiplier,
      highlightRanges,
      charOffset,
    ),
    EpubAnchorNode n => _renderAnchor(
      n,
      styleMap,
      fontSizeMultiplier,
      highlightRanges,
      charOffset,
    ),
    EpubListItemNode n => _renderNodes(
      n.children,
      styleMap,
      fontSizeMultiplier,
      highlightRanges,
      charOffset,
    ),
  };

  Widget _renderAnchor(
    EpubAnchorNode node,
    Map<int, ComputedStyle> styleMap,
    double fontSizeMultiplier,
    List<(int, int)> highlightRanges,
    int charOffset,
  ) {
    if (node.child == null) return const SizedBox.shrink();
    return _renderNode(
          node.child!,
          styleMap,
          fontSizeMultiplier,
          highlightRanges,
          charOffset,
        ) ??
        const SizedBox.shrink();
  }

  Widget _renderParagraph(
    EpubParagraphNode node,
    Map<int, ComputedStyle> styleMap,
    double fontSizeMultiplier,
    List<(int, int)> highlightRanges,
    int charOffset,
  ) {
    if (node.children.isEmpty) return const SizedBox.shrink();

    final style = styleMap[node.nodeId];
    if (style?.isHidden ?? false) return const SizedBox.shrink();

    final rootFontSize = 16.0 * fontSizeMultiplier;
    final textStyle = style != null
        ? StyleApplicator.toTextStyle(style, baseFontSize: rootFontSize)
        : null;
    final textAlign = style != null
        ? StyleApplicator.parseTextAlign(style.getValue('text-align'))
        : null;
    final padding = style != null
        ? StyleApplicator.parseEdgeInsets(style, 'padding')
        : null;
    final margin = style != null
        ? StyleApplicator.parseEdgeInsets(style, 'margin')
        : null;
    final decoration = style != null
        ? StyleApplicator.toBoxDecoration(style)
        : null;
    final textIndent = style != null
        ? StyleApplicator.parseLength(
            style.getValue('text-indent'),
            parentFontSize: textStyle?.fontSize ?? rootFontSize,
          )
        : null;

    int inlineOffset = charOffset;
    final inlineSpans = <InlineSpan>[];
    for (final child in node.children) {
      inlineSpans.add(_renderInlineSpan(
        child,
        textStyle,
        styleMap,
        fontSizeMultiplier,
        highlightRanges,
        inlineOffset,
      ));
      inlineOffset += child.extractText().length;
    }

    Widget content = Text.rich(
      TextSpan(children: inlineSpans),
      style: textStyle,
      textAlign: textAlign,
    );

    if (textIndent != null && textIndent > 0) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: textIndent),
          Expanded(child: content),
        ],
      );
    }

    if (padding != null || decoration != null) {
      content = Container(
        padding: padding,
        decoration: decoration,
        child: content,
      );
    }

    return Padding(
      padding: margin ?? const EdgeInsets.only(bottom: 12),
      child: content,
    );
  }

  InlineSpan _renderInlineSpan(
    EpubContentNode node,
    TextStyle? parentTextStyle,
    Map<int, ComputedStyle> styleMap,
    double fontSizeMultiplier,
    List<(int, int)> highlightRanges,
    int nodeCharOffset,
  ) {
    if (node is EpubTextNode) {
      if (node.isLink) {
        return TextSpan(
          text: node.text,
          style: const TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () =>
                _viewModel.onAction(LinkTapped(node.linkHref ?? '')),
        );
      }

      final emphasisStyle = switch (node.emphasis) {
        TextEmphasis.bold => const TextStyle(fontWeight: FontWeight.bold),
        TextEmphasis.italic => const TextStyle(fontStyle: FontStyle.italic),
        TextEmphasis.boldItalic => const TextStyle(
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        ),
        TextEmphasis.none => null,
      };

      final rootFontSize = 16.0 * fontSizeMultiplier;
      final cssStyle = styleMap[node.nodeId]?.let(
        (s) => StyleApplicator.toTextStyle(
          s,
          parentFontSize: parentTextStyle?.fontSize ?? rootFontSize,
          baseFontSize: rootFontSize,
        ),
      );

      final mergedStyle = cssStyle != null
          ? (emphasisStyle != null ? emphasisStyle.merge(cssStyle) : cssStyle)
          : emphasisStyle;

      final text = StyleApplicator.applyTextTransform(
        node.text,
        styleMap[node.nodeId]?.getValue('text-transform'),
      );

      return _buildHighlightedSpan(text, mergedStyle, highlightRanges, nodeCharOffset);
    }

    if (node is EpubLineBreakNode) return const TextSpan(text: '\n');

    if (node is EpubImageNode) {
      final w = _renderImage(node);
      return w != null ? WidgetSpan(child: w) : const TextSpan();
    }

    if (node is EpubInlineImageNode) {
      return WidgetSpan(child: _renderInlineImage(node));
    }

    return const TextSpan();
  }

  InlineSpan _buildHighlightedSpan(
    String text,
    TextStyle? style,
    List<(int, int)> highlightRanges,
    int nodeCharStart,
  ) {
    final nodeCharEnd = nodeCharStart + text.length;
    final highlightStyle =
        (style ?? const TextStyle()).copyWith(backgroundColor: appHighlight);

    for (final (hlStart, hlEnd) in highlightRanges) {
      if (hlStart >= nodeCharEnd || hlEnd <= nodeCharStart) continue;
      final overlapStart =
          (hlStart - nodeCharStart).clamp(0, text.length);
      final overlapEnd =
          (hlEnd - nodeCharStart).clamp(0, text.length);
      return TextSpan(children: [
        if (overlapStart > 0)
          TextSpan(text: text.substring(0, overlapStart), style: style),
        TextSpan(
          text: text.substring(overlapStart, overlapEnd),
          style: highlightStyle,
        ),
        if (overlapEnd < text.length)
          TextSpan(text: text.substring(overlapEnd), style: style),
      ]);
    }
    return TextSpan(text: text, style: style);
  }

  Widget _renderHeading(
    EpubHeadingNode node,
    Map<int, ComputedStyle> styleMap,
    double fontSizeMultiplier,
    List<(int, int)> highlightRanges,
    int charOffset,
  ) {
    const sizes = {1: 28.0, 2: 24.0, 3: 20.0, 4: 18.0, 5: 16.0, 6: 14.0};
    final rootFontSize = 16.0 * fontSizeMultiplier;
    final fallbackSize = (sizes[node.level] ?? 16.0) * fontSizeMultiplier;

    final style = styleMap[node.nodeId];
    if (style?.isHidden ?? false) return const SizedBox.shrink();

    final cssStyle = style != null
        ? StyleApplicator.toTextStyle(
            style,
            parentFontSize: fallbackSize,
            baseFontSize: rootFontSize,
          )
        : null;

    final textAlign = style != null
        ? StyleApplicator.parseTextAlign(style.getValue('text-align'))
        : null;
    final margin = style != null
        ? StyleApplicator.parseEdgeInsets(style, 'margin')
        : null;
    final decoration = style != null
        ? StyleApplicator.toBoxDecoration(style)
        : null;

    final headingStyle = TextStyle(
      fontSize: fallbackSize,
      fontWeight: FontWeight.bold,
    ).merge(cssStyle);

    int inlineOffset = charOffset;
    final inlineSpans = <InlineSpan>[];
    for (final child in node.children) {
      inlineSpans.add(_renderInlineSpan(
        child,
        headingStyle,
        styleMap,
        fontSizeMultiplier,
        highlightRanges,
        inlineOffset,
      ));
      inlineOffset += child.extractText().length;
    }

    Widget content = Text.rich(
      TextSpan(children: inlineSpans),
      style: headingStyle,
      textAlign: textAlign,
    );

    if (decoration != null) {
      content = Container(decoration: decoration, child: content);
    }

    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(vertical: 12),
      child: content,
    );
  }

  Widget? _renderImage(EpubImageNode node) {
    final book = _viewModel.state.book!;
    final bytes = _viewModel.imageCache.putIfAbsent(node.resolvedHref, () {
      final file = book.fileMap[node.resolvedHref];
      if (file == null) return Uint8List(0);
      return Uint8List.fromList(file.content as List<int>);
    });
    if (bytes.isEmpty) return null;
    return _imageWidget(bytes);
  }

  Widget _renderInlineImage(EpubInlineImageNode node) =>
      _imageWidget(node.bytes);

  Widget _imageWidget(Uint8List bytes) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Image.memory(
        bytes,
        fit: BoxFit.contain,
        cacheWidth: 1200,
        errorBuilder: (ctx, err, st) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _renderList(
    EpubListNode node,
    Map<int, ComputedStyle> styleMap,
    double fontSizeMultiplier,
    List<(int, int)> highlightRanges,
    int charOffset,
  ) {
    int itemOffset = charOffset;
    final rows = <Widget>[];
    for (int i = 0; i < node.items.length; i++) {
      final item = node.items[i];
      final bullet = node.ordered ? '${i + 1}.' : '•';
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 28, child: Text(bullet)),
          Expanded(
            child: _renderNodes(
              item.children,
              styleMap,
              fontSizeMultiplier,
              highlightRanges,
              itemOffset,
            ),
          ),
        ],
      ));
      itemOffset += item.extractText().length;
    }
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  Widget _renderBlockquote(
    EpubBlockquoteNode node,
    Map<int, ComputedStyle> styleMap,
    double fontSizeMultiplier,
    List<(int, int)> highlightRanges,
    int charOffset,
  ) {
    final style = styleMap[node.nodeId];
    final decoration = style != null
        ? StyleApplicator.toBoxDecoration(style)
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration:
          decoration ??
          BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.outline,
                width: 4,
              ),
            ),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
      child: _renderNodes(
        node.children,
        styleMap,
        fontSizeMultiplier,
        highlightRanges,
        charOffset,
      ),
    );
  }
}

extension _NullableExt<T> on T? {
  R? let<R>(R Function(T) fn) {
    final self = this;
    return self != null ? fn(self) : null;
  }
}
