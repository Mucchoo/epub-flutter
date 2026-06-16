import 'dart:typed_data';

import 'package:html/dom.dart' as dom;

enum TextEmphasis { none, bold, italic, boldItalic }

sealed class EpubContentNode {
  final dom.Element? domElement;
  final int? nodeId;
  const EpubContentNode({this.domElement, this.nodeId});
}

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
    super.domElement,
    super.nodeId,
  });
}

class EpubParagraphNode extends EpubContentNode {
  final List<EpubContentNode> children;
  EpubParagraphNode(this.children, {super.domElement, super.nodeId});
}

class EpubHeadingNode extends EpubContentNode {
  final int level;
  final List<EpubContentNode> children;
  EpubHeadingNode({
    required this.level,
    required this.children,
    super.domElement,
    super.nodeId,
  });
}

class EpubImageNode extends EpubContentNode {
  final String resolvedHref;
  EpubImageNode(this.resolvedHref, {super.domElement, super.nodeId});
}

class EpubInlineImageNode extends EpubContentNode {
  final Uint8List bytes;
  EpubInlineImageNode(this.bytes, {super.domElement, super.nodeId});
}

class EpubListNode extends EpubContentNode {
  final bool ordered;
  final List<EpubListItemNode> items;
  EpubListNode({required this.ordered, required this.items, super.domElement, super.nodeId});
}

class EpubListItemNode extends EpubContentNode {
  final List<EpubContentNode> children;
  EpubListItemNode(this.children, {super.domElement, super.nodeId});
}

class EpubBlockquoteNode extends EpubContentNode {
  final List<EpubContentNode> children;
  EpubBlockquoteNode(this.children, {super.domElement, super.nodeId});
}

class EpubAnchorNode extends EpubContentNode {
  final String id;
  final EpubContentNode? child;
  EpubAnchorNode({required this.id, this.child, super.domElement, super.nodeId});
}

class EpubLineBreakNode extends EpubContentNode {
  const EpubLineBreakNode() : super(domElement: null, nodeId: null);
}

class EpubDividerNode extends EpubContentNode {
  const EpubDividerNode() : super(domElement: null, nodeId: null);
}
