import 'dart:typed_data';

enum TextEmphasis { none, bold, italic, boldItalic }

sealed class EpubContentNode {}

class EpubTextNode extends EpubContentNode {
  final String text;
  final TextEmphasis emphasis;
  final bool isLink;
  final String? linkHref;

  EpubTextNode({
    required this.text,
    this.emphasis = TextEmphasis.none,
    this.isLink = false,
    this.linkHref,
  });
}

class EpubParagraphNode extends EpubContentNode {
  final List<EpubContentNode> children;
  EpubParagraphNode(this.children);
}

class EpubHeadingNode extends EpubContentNode {
  final int level;
  final List<EpubContentNode> children;
  EpubHeadingNode({required this.level, required this.children});
}

class EpubImageNode extends EpubContentNode {
  final String resolvedHref;
  EpubImageNode(this.resolvedHref);
}

class EpubInlineImageNode extends EpubContentNode {
  final Uint8List bytes;
  EpubInlineImageNode(this.bytes);
}

class EpubListNode extends EpubContentNode {
  final bool ordered;
  final List<EpubListItemNode> items;
  EpubListNode({required this.ordered, required this.items});
}

class EpubListItemNode extends EpubContentNode {
  final List<EpubContentNode> children;
  EpubListItemNode(this.children);
}

class EpubBlockquoteNode extends EpubContentNode {
  final List<EpubContentNode> children;
  EpubBlockquoteNode(this.children);
}

class EpubAnchorNode extends EpubContentNode {
  final String id;
  final EpubContentNode? child;
  EpubAnchorNode({required this.id, this.child});
}

class EpubLineBreakNode extends EpubContentNode {}

class EpubDividerNode extends EpubContentNode {}
