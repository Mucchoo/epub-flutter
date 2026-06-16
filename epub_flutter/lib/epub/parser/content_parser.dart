import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../models/epub_content_node.dart';
import 'path_utils.dart';

class ContentParser {
  final String chapterHref;
  final Map<String, ArchiveFile>? fileMap;
  final Set<String>? knownFilePaths;

  late dom.Document _doc;
  int _nextNodeId = 0;

  ContentParser({
    required this.chapterHref,
    this.fileMap,
    this.knownFilePaths,
  });

  /// Paths to linked stylesheets, resolved relative to this chapter.
  /// Only available after [parse] or [parseForStylesheetInfo] has been called.
  List<String> get linkedStylesheetPaths {
    final known = knownFilePaths ?? fileMap?.keys.toSet() ?? const <String>{};
    return _doc
        .querySelectorAll('link[rel="stylesheet"]')
        .map((el) => el.attributes['href'] ?? '')
        .where((href) => href.isNotEmpty)
        .map((href) => resolveHref(chapterHref, href))
        .where((path) => known.contains(path))
        .toList();
  }

  /// Text content of embedded <style> elements.
  /// Only available after [parse] or [parseForStylesheetInfo] has been called.
  List<String> get embeddedStyleTexts {
    return _doc
        .querySelectorAll('style')
        .map((el) => el.text)
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Fast path: parse just enough HTML to populate [linkedStylesheetPaths]
  /// and [embeddedStyleTexts]. Does NOT build the node tree.
  /// Used on the main thread to gather CSS info before spawning an isolate.
  void parseForStylesheetInfo(List<int> bytes) {
    _doc = html_parser.parse(utf8.decode(_stripBom(bytes)));
  }

  /// Full parse: builds the [EpubContentNode] tree with [nodeId]s assigned.
  List<EpubContentNode> parse(List<int> bytes) {
    _doc = html_parser.parse(utf8.decode(_stripBom(bytes)));
    final body = _doc.body;
    if (body == null) return [];
    _nextNodeId = 0;
    return _parseChildren(body.nodes);
  }

  List<int> _stripBom(List<int> bytes) {
    return (bytes.length >= 3 &&
            bytes[0] == 0xEF &&
            bytes[1] == 0xBB &&
            bytes[2] == 0xBF)
        ? bytes.sublist(3)
        : bytes;
  }

  List<EpubContentNode> _parseChildren(List<dom.Node> nodes) {
    final result = <EpubContentNode>[];
    for (final node in nodes) {
      final parsed = _parseNode(node);
      if (parsed != null) result.add(parsed);
    }
    return result;
  }

  EpubContentNode? _parseNode(dom.Node node) {
    if (node is dom.Text) {
      final collapsed = node.text.replaceAll(RegExp(r'\s+'), ' ');
      if (collapsed.trim().isEmpty) return null;
      return EpubTextNode(text: collapsed);
    }
    if (node is! dom.Element) return null;
    final tag = node.localName?.toLowerCase() ?? '';

    final nodeId = node.attributes['id'];
    EpubContentNode? wrap(EpubContentNode? inner) {
      if (nodeId == null || nodeId.isEmpty) return inner;
      return EpubAnchorNode(
        id: nodeId,
        child: inner,
        domElement: node,
        nodeId: _nextNodeId++,
      );
    }

    return switch (tag) {
      'p' || 'div' => wrap(
          EpubParagraphNode(
            _parseInlineChildren(node.nodes),
            domElement: node,
            nodeId: _nextNodeId++,
          ),
        ),
      'h1' => wrap(
          EpubHeadingNode(
            level: 1,
            children: _parseInlineChildren(node.nodes),
            domElement: node,
            nodeId: _nextNodeId++,
          ),
        ),
      'h2' => wrap(
          EpubHeadingNode(
            level: 2,
            children: _parseInlineChildren(node.nodes),
            domElement: node,
            nodeId: _nextNodeId++,
          ),
        ),
      'h3' => wrap(
          EpubHeadingNode(
            level: 3,
            children: _parseInlineChildren(node.nodes),
            domElement: node,
            nodeId: _nextNodeId++,
          ),
        ),
      'h4' => wrap(
          EpubHeadingNode(
            level: 4,
            children: _parseInlineChildren(node.nodes),
            domElement: node,
            nodeId: _nextNodeId++,
          ),
        ),
      'h5' => wrap(
          EpubHeadingNode(
            level: 5,
            children: _parseInlineChildren(node.nodes),
            domElement: node,
            nodeId: _nextNodeId++,
          ),
        ),
      'h6' => wrap(
          EpubHeadingNode(
            level: 6,
            children: _parseInlineChildren(node.nodes),
            domElement: node,
            nodeId: _nextNodeId++,
          ),
        ),
      'ul' => wrap(_parseList(node, ordered: false)),
      'ol' => wrap(_parseList(node, ordered: true)),
      'blockquote' => wrap(
          EpubBlockquoteNode(
            _parseChildren(node.nodes),
            domElement: node,
            nodeId: _nextNodeId++,
          ),
        ),
      'img' => wrap(_parseImage(node)),
      'figure' => wrap(_parseFigure(node)),
      'br' => const EpubLineBreakNode(),
      'hr' => const EpubDividerNode(),
      'section' ||
      'article' ||
      'main' ||
      'aside' ||
      'header' ||
      'footer' ||
      'nav' =>
        () {
          final children = _parseChildren(node.nodes);
          if (children.length == 1) {
            return nodeId != null
                ? EpubAnchorNode(
                    id: nodeId,
                    child: children.first,
                    domElement: node,
                    nodeId: _nextNodeId++,
                  )
                : children.first;
          }
          return wrap(
            EpubParagraphNode(
              children.whereType<EpubContentNode>().toList(),
              domElement: node,
              nodeId: _nextNodeId++,
            ),
          );
        }(),
      'span' || 'a' || 'strong' || 'em' || 'b' || 'i' => wrap(
          EpubParagraphNode(
            _parseInlineChildren([node]),
            domElement: node,
            nodeId: _nextNodeId++,
          ),
        ),
      'script' || 'style' || 'head' || 'meta' || 'link' || 'noscript' => null,
      _ => () {
          final children = _parseChildren(node.nodes);
          if (children.isEmpty) return null;
          if (children.length == 1) {
            return nodeId != null
                ? EpubAnchorNode(
                    id: nodeId,
                    child: children.first,
                    domElement: node,
                    nodeId: _nextNodeId++,
                  )
                : children.first;
          }
          return wrap(
            EpubParagraphNode(
              children.whereType<EpubContentNode>().toList(),
              domElement: node,
              nodeId: _nextNodeId++,
            ),
          );
        }(),
    };
  }

  List<EpubContentNode> _parseInlineChildren(List<dom.Node> nodes) {
    final result = <EpubContentNode>[];
    for (final node in nodes) {
      if (node is dom.Text) {
        final text = node.text.replaceAll(RegExp(r'\s+'), ' ');
        if (text.isNotEmpty) result.add(EpubTextNode(text: text));
      } else if (node is dom.Element) {
        final tag = node.localName?.toLowerCase() ?? '';
        switch (tag) {
          case 'strong' || 'b':
            result.addAll(
              _parseInlineWithEmphasis(node.nodes, TextEmphasis.bold),
            );
          case 'em' || 'i':
            result.addAll(
              _parseInlineWithEmphasis(node.nodes, TextEmphasis.italic),
            );
          case 'a':
            final rawHref = node.attributes['href'] ?? '';
            if (rawHref.isNotEmpty) {
              result.add(EpubTextNode(
                text: node.text,
                isLink: true,
                linkHref: _resolveHref(rawHref),
                domElement: node,
                nodeId: _nextNodeId++,
              ));
            } else {
              result.addAll(_parseInlineChildren(node.nodes));
            }
          case 'img':
            final image = _parseImage(node);
            if (image != null) result.add(image);
          case 'br':
            result.add(const EpubLineBreakNode());
          case 'span' || 'sup' || 'sub' || 'code' || 'abbr':
            result.addAll(_parseInlineChildren(node.nodes));
          default:
            result.addAll(_parseInlineChildren(node.nodes));
        }
      }
    }
    return result;
  }

  List<EpubContentNode> _parseInlineWithEmphasis(
    List<dom.Node> nodes,
    TextEmphasis emphasis,
  ) {
    return _parseInlineChildren(nodes).map((node) {
      if (node is EpubTextNode && !node.isLink) {
        final combined =
            emphasis == TextEmphasis.bold && node.emphasis == TextEmphasis.italic
                ? TextEmphasis.boldItalic
                : emphasis == TextEmphasis.italic &&
                        node.emphasis == TextEmphasis.bold
                    ? TextEmphasis.boldItalic
                    : emphasis;
        return EpubTextNode(
          text: node.text,
          emphasis: combined,
          isLink: node.isLink,
          linkHref: node.linkHref,
          domElement: node.domElement,
          nodeId: node.nodeId,
        );
      }
      return node;
    }).toList();
  }

  EpubContentNode? _parseImage(dom.Element el) {
    final src = el.attributes['src'] ??
        el.attributes['xlink:href'] ??
        el.attributes['href'] ??
        '';
    if (src.isEmpty) return null;
    if (src.startsWith('data:')) return _parseDataUri(src);

    final resolved = _resolveHref(src);
    final withoutFragment = resolved.split('#').first;

    final known =
        knownFilePaths ?? fileMap?.keys.toSet() ?? const <String>{};
    if (known.contains(withoutFragment)) {
      return EpubImageNode(withoutFragment, domElement: el);
    }
    if (known.contains(resolved)) {
      return EpubImageNode(resolved, domElement: el);
    }
    return null;
  }

  EpubContentNode? _parseFigure(dom.Element el) {
    final img = el.querySelector('img');
    return img != null ? _parseImage(img) : null;
  }

  EpubListNode _parseList(dom.Element el, {required bool ordered}) {
    final items = el.children
        .where((c) => c.localName == 'li')
        .map(
          (li) => EpubListItemNode(
            _parseChildren(li.nodes),
            domElement: li,
            nodeId: _nextNodeId++,
          ),
        )
        .toList();
    return EpubListNode(
      ordered: ordered,
      items: items,
      domElement: el,
      nodeId: _nextNodeId++,
    );
  }

  EpubContentNode? _parseDataUri(String dataUri) {
    final commaIndex = dataUri.indexOf(',');
    if (commaIndex == -1) return null;
    try {
      final bytes = Uri.parse(dataUri).data?.contentAsBytes();
      if (bytes == null) return null;
      return EpubInlineImageNode(Uint8List.fromList(bytes));
    } catch (_) {
      return null;
    }
  }

  String _resolveHref(String rawHref) {
    if (rawHref.startsWith('http://') || rawHref.startsWith('https://')) {
      return rawHref;
    }
    return resolveHref(chapterHref, rawHref);
  }
}
