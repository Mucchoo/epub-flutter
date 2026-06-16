import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../epub/models/epub_content_node.dart';
import '../../epub/styling/computed_style.dart';
import '../../epub/styling/style_applicator.dart';

typedef NodeKey = ({GlobalKey key, int domIndex, String? elementId});

class ContentRenderer {
  final Map<String, ArchiveFile> fileMap;
  final Map<String, Uint8List> _imageCache = {};
  final void Function(String href, String? fragment) onLinkTap;
  final ComputedStyleMap styleMap;
  final double fontSizeMultiplier;

  ContentRenderer({
    required this.fileMap,
    required this.onLinkTap,
    this.styleMap = const {},
    this.fontSizeMultiplier = 1.0,
  });

  Widget render(List<EpubContentNode> nodes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: nodes.map(_renderNode).whereType<Widget>().toList(),
    );
  }

  ({Widget widget, List<NodeKey> nodeKeys}) renderWithKeys(
    List<EpubContentNode> nodes,
  ) {
    final keys = <NodeKey>[];
    int elementCounter = 0;
    final widgets = <Widget>[];

    for (final node in nodes) {
      elementCounter++;
      final domIndex = elementCounter * 2;
      final key = GlobalKey();
      final elementId = node is EpubAnchorNode ? node.id : null;
      keys.add((key: key, domIndex: domIndex, elementId: elementId));
      final inner = _renderNode(node);
      if (inner != null) widgets.add(KeyedSubtree(key: key, child: inner));
    }

    return (
      widget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
      nodeKeys: keys,
    );
  }

  Widget? _renderNode(EpubContentNode node) => switch (node) {
        EpubParagraphNode n => _renderParagraph(n),
        EpubHeadingNode n => _renderHeading(n),
        EpubImageNode n => _renderImage(n),
        EpubInlineImageNode n => _renderInlineImage(n),
        EpubListNode n => _renderList(n),
        EpubBlockquoteNode n => _renderBlockquote(n),
        EpubLineBreakNode _ => const SizedBox(height: 8),
        EpubDividerNode _ => const Divider(),
        EpubTextNode n => _renderParagraph(EpubParagraphNode([n])),
        EpubAnchorNode n => _renderAnchor(n),
        EpubListItemNode n => render(n.children),
      };

  Widget _renderAnchor(EpubAnchorNode node) {
    if (node.child == null) return const SizedBox.shrink();
    return _renderNode(node.child!) ?? const SizedBox.shrink();
  }

  Widget _renderParagraph(EpubParagraphNode node) {
    if (node.children.isEmpty) return const SizedBox.shrink();

    final style = node.domElement != null ? styleMap[node.domElement!] : null;
    if (style?.isHidden ?? false) return const SizedBox.shrink();

    final rootFontSize = 16.0 * fontSizeMultiplier;
    final rawTextStyle = style != null
        ? StyleApplicator.toTextStyle(style, baseFontSize: rootFontSize)
        : null;
    final textStyle = rawTextStyle != null
        ? rawTextStyle.copyWith(
            fontSize: (rawTextStyle.fontSize ?? 16.0) * fontSizeMultiplier,
          )
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
            .map((child) => _renderInlineSpan(child, textStyle))
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

    final effectiveMargin = margin ?? const EdgeInsets.only(bottom: 12);
    return Padding(padding: effectiveMargin, child: content);
  }

  InlineSpan _renderInlineSpan(
    EpubContentNode node, [
    TextStyle? parentTextStyle,
  ]) {
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

      // Merge CSS-derived style with emphasis
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
      // CSS style for inline elements (e.g. <span> with domElement)
      final rawCssStyle = node.domElement != null
          ? styleMap[node.domElement!].let(
              (s) => StyleApplicator.toTextStyle(
                s,
                parentFontSize: parentTextStyle?.fontSize ?? rootFontSize,
                baseFontSize: rootFontSize,
              ),
            )
          : null;
      final cssStyle = rawCssStyle != null
          ? rawCssStyle.copyWith(
              fontSize: (rawCssStyle.fontSize ?? 16.0) * fontSizeMultiplier,
            )
          : null;

      final mergedStyle = cssStyle != null
          ? (emphasisStyle != null ? emphasisStyle.merge(cssStyle) : cssStyle)
          : emphasisStyle;

      final text = StyleApplicator.applyTextTransform(
        node.text,
        node.domElement != null
            ? styleMap[node.domElement!]?.getValue('text-transform')
            : null,
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

  Widget _renderHeading(EpubHeadingNode node) {
    const sizes = {1: 28.0, 2: 24.0, 3: 20.0, 4: 18.0, 5: 16.0, 6: 14.0};
    final fallbackSize = (sizes[node.level] ?? 16.0) * fontSizeMultiplier;
    final rootFontSize = 16.0 * fontSizeMultiplier;

    final style =
        node.domElement != null ? styleMap[node.domElement!] : null;
    if (style?.isHidden ?? false) return const SizedBox.shrink();

    final rawCssStyle = style != null
        ? StyleApplicator.toTextStyle(
            style,
            parentFontSize: fallbackSize,
            baseFontSize: rootFontSize,
          )
        : null;
    final cssStyle = rawCssStyle != null
        ? rawCssStyle.copyWith(
            fontSize: (rawCssStyle.fontSize ?? fallbackSize) * fontSizeMultiplier,
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

    // If CSS doesn't provide a font-size, use the fallback heading size
    final headingStyle = TextStyle(
      fontSize: fallbackSize,
      fontWeight: FontWeight.bold,
    ).merge(cssStyle);

    Widget content = Text.rich(
      TextSpan(
        children: node.children
            .map((child) => _renderInlineSpan(child, headingStyle))
            .toList(),
      ),
      style: headingStyle,
      textAlign: textAlign,
    );

    if (decoration != null) {
      content = Container(decoration: decoration, child: content);
    }

    final effectiveMargin =
        margin ?? const EdgeInsets.symmetric(vertical: 12);
    return Padding(padding: effectiveMargin, child: content);
  }

  Widget? _renderImage(EpubImageNode node) {
    final bytes = _imageCache.putIfAbsent(node.resolvedHref, () {
      final file = fileMap[node.resolvedHref];
      if (file == null) return Uint8List(0);
      return Uint8List.fromList(file.content as List<int>);
    });
    if (bytes.isEmpty) return null;
    return _imageWidget(bytes);
  }

  Widget _renderInlineImage(EpubInlineImageNode node) {
    return _imageWidget(node.bytes);
  }

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

  Widget _renderList(EpubListNode node) {
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
              Expanded(child: render(entry.value.children)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _renderBlockquote(EpubBlockquoteNode node) {
    final style =
        node.domElement != null ? styleMap[node.domElement!] : null;
    final decoration = style != null
        ? StyleApplicator.toBoxDecoration(style)
        : null;

    return Builder(
      builder: (context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: decoration ??
            BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                  width: 4,
                ),
              ),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
        child: render(node.children),
      ),
    );
  }

  void _handleLinkTap(String href) {
    if (href.startsWith('http://') || href.startsWith('https://')) {
      launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
    } else {
      final uri = Uri.parse(href);
      onLinkTap(uri.path, uri.fragment.isEmpty ? null : uri.fragment);
    }
  }
}

extension _NullableExt<T> on T? {
  R? let<R>(R Function(T) fn) {
    final self = this;
    return self != null ? fn(self) : null;
  }
}
