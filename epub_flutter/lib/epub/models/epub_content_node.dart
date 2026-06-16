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

  EpubTextNode withoutDom() => EpubTextNode(
        text: text,
        emphasis: emphasis,
        isLink: isLink,
        linkHref: linkHref,
        nodeId: nodeId,
      );
}

class EpubParagraphNode extends EpubContentNode {
  final List<EpubContentNode> children;
  EpubParagraphNode(this.children, {super.domElement, super.nodeId});

  EpubParagraphNode withoutDom() =>
      EpubParagraphNode(children.stripDom(), nodeId: nodeId);
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

  EpubHeadingNode withoutDom() =>
      EpubHeadingNode(level: level, children: children.stripDom(), nodeId: nodeId);
}

class EpubImageNode extends EpubContentNode {
  final String resolvedHref;
  EpubImageNode(this.resolvedHref, {super.domElement, super.nodeId});

  EpubImageNode withoutDom() => EpubImageNode(resolvedHref, nodeId: nodeId);
}

class EpubInlineImageNode extends EpubContentNode {
  final Uint8List bytes;
  EpubInlineImageNode(this.bytes, {super.domElement, super.nodeId});

  EpubInlineImageNode withoutDom() => EpubInlineImageNode(bytes, nodeId: nodeId);
}

class EpubListNode extends EpubContentNode {
  final bool ordered;
  final List<EpubListItemNode> items;
  EpubListNode({required this.ordered, required this.items, super.domElement, super.nodeId});

  EpubListNode withoutDom() => EpubListNode(
        ordered: ordered,
        items: items.map((i) => i.withoutDom()).toList(),
        nodeId: nodeId,
      );
}

class EpubListItemNode extends EpubContentNode {
  final List<EpubContentNode> children;
  EpubListItemNode(this.children, {super.domElement, super.nodeId});

  EpubListItemNode withoutDom() =>
      EpubListItemNode(children.stripDom(), nodeId: nodeId);
}

class EpubBlockquoteNode extends EpubContentNode {
  final List<EpubContentNode> children;
  EpubBlockquoteNode(this.children, {super.domElement, super.nodeId});

  EpubBlockquoteNode withoutDom() =>
      EpubBlockquoteNode(children.stripDom(), nodeId: nodeId);
}

class EpubAnchorNode extends EpubContentNode {
  final String id;
  final EpubContentNode? child;
  EpubAnchorNode({required this.id, this.child, super.domElement, super.nodeId});

  EpubAnchorNode withoutDom() =>
      EpubAnchorNode(id: id, child: child?.withoutDom(), nodeId: nodeId);
}

class EpubLineBreakNode extends EpubContentNode {
  const EpubLineBreakNode() : super(domElement: null, nodeId: null);
}

class EpubDividerNode extends EpubContentNode {
  const EpubDividerNode() : super(domElement: null, nodeId: null);
}

extension StripDomExtension on EpubContentNode {
  EpubContentNode withoutDom() => switch (this) {
        EpubTextNode n => n.withoutDom(),
        EpubParagraphNode n => n.withoutDom(),
        EpubHeadingNode n => n.withoutDom(),
        EpubImageNode n => n.withoutDom(),
        EpubInlineImageNode n => n.withoutDom(),
        EpubListNode n => n.withoutDom(),
        EpubListItemNode n => n.withoutDom(),
        EpubBlockquoteNode n => n.withoutDom(),
        EpubAnchorNode n => n.withoutDom(),
        EpubLineBreakNode _ => const EpubLineBreakNode(),
        EpubDividerNode _ => const EpubDividerNode(),
      };
}

extension StripDomListExtension on List<EpubContentNode> {
  List<EpubContentNode> stripDom() => map((n) => n.withoutDom()).toList();
}
