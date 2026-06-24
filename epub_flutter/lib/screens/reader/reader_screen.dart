import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../epub/models/epub_content_node.dart';
import '../../epub/styling/computed_style.dart';
import '../../epub/styling/style_applicator.dart';
import '../../theme/app_colors.dart';
import '../settings/reading_settings_notifier.dart';
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
                contextMenuBuilder: (context, selectableRegionState) {
                  return AdaptiveTextSelectionToolbar.buttonItems(
                    anchors: selectableRegionState.contextMenuAnchors,
                    buttonItems: [
                      ContextMenuButtonItem(
                        label: 'Ask AI',
                        onPressed: () {
                          ContextMenuController.removeAny();
                        },
                      ),
                      ContextMenuButtonItem(
                        label: 'Highlight',
                        onPressed: () {
                          ContextMenuController.removeAny();
                        },
                      ),
                      ContextMenuButtonItem(
                        label: 'Copy',
                        onPressed: () {
                          selectableRegionState.copySelection(
                            SelectionChangedCause.toolbar,
                          );
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
                    print('[listview] building item index=$index isRestoring=${state.isRestoring}');
                    final data = state.chapterData[index];
                    if (data == null || data.nodes.isEmpty) {
                      print('[listview] chapter $index has no data — returning SizedBox.shrink');
                      return const SizedBox.shrink();
                    }
                    print('[listview] chapter $index has ${data.nodes.length} nodes, key=${_viewModel.chapterKeys[index]}');
                    return KeyedSubtree(
                      key: _viewModel.chapterKeys[index],
                      child: _renderNodes(
                        data.nodes,
                        data.styleMap,
                        fontSizeMultiplier,
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
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: nodes
          .map((n) => _renderNode(n, styleMap, fontSizeMultiplier))
          .whereType<Widget>()
          .toList(),
    );
  }

  Widget? _renderNode(
    EpubContentNode node,
    Map<int, ComputedStyle> styleMap,
    double fontSizeMultiplier,
  ) => switch (node) {
    EpubParagraphNode n => _renderParagraph(n, styleMap, fontSizeMultiplier),
    EpubHeadingNode n => _renderHeading(n, styleMap, fontSizeMultiplier),
    EpubImageNode n => _renderImage(n),
    EpubInlineImageNode n => _renderInlineImage(n),
    EpubListNode n => _renderList(n, styleMap, fontSizeMultiplier),
    EpubBlockquoteNode n => _renderBlockquote(n, styleMap, fontSizeMultiplier),
    EpubLineBreakNode _ => const SizedBox(height: 8),
    EpubDividerNode _ => const Divider(),
    EpubTextNode n => _renderParagraph(
      EpubParagraphNode([n]),
      styleMap,
      fontSizeMultiplier,
    ),
    EpubAnchorNode n => _renderAnchor(n, styleMap, fontSizeMultiplier),
    EpubListItemNode n => _renderNodes(
      n.children,
      styleMap,
      fontSizeMultiplier,
    ),
  };

  Widget _renderAnchor(
    EpubAnchorNode node,
    Map<int, ComputedStyle> styleMap,
    double fontSizeMultiplier,
  ) {
    if (node.child == null) return const SizedBox.shrink();
    return _renderNode(node.child!, styleMap, fontSizeMultiplier) ??
        const SizedBox.shrink();
  }

  Widget _renderParagraph(
    EpubParagraphNode node,
    Map<int, ComputedStyle> styleMap,
    double fontSizeMultiplier,
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

    Widget content = Text.rich(
      TextSpan(
        children: node.children
            .map(
              (child) => _renderInlineSpan(
                child,
                textStyle,
                styleMap,
                fontSizeMultiplier,
              ),
            )
            .toList(),
      ),
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
            ..onTap = () => _handleLinkTap(node.linkHref ?? ''),
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

      return TextSpan(text: text, style: mergedStyle);
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

  Widget _renderHeading(
    EpubHeadingNode node,
    Map<int, ComputedStyle> styleMap,
    double fontSizeMultiplier,
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

    Widget content = Text.rich(
      TextSpan(
        children: node.children
            .map(
              (child) => _renderInlineSpan(
                child,
                headingStyle,
                styleMap,
                fontSizeMultiplier,
              ),
            )
            .toList(),
      ),
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
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: node.items.asMap().entries.map((entry) {
          final bullet = node.ordered ? '${entry.key + 1}.' : '•';
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 28, child: Text(bullet)),
              Expanded(
                child: _renderNodes(
                  entry.value.children,
                  styleMap,
                  fontSizeMultiplier,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _renderBlockquote(
    EpubBlockquoteNode node,
    Map<int, ComputedStyle> styleMap,
    double fontSizeMultiplier,
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
      child: _renderNodes(node.children, styleMap, fontSizeMultiplier),
    );
  }

  void _handleLinkTap(String href) {
    if (href.startsWith('http://') || href.startsWith('https://')) {
      launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
    }
  }
}

extension _NullableExt<T> on T? {
  R? let<R>(R Function(T) fn) {
    final self = this;
    return self != null ? fn(self) : null;
  }
}
