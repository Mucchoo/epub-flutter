import 'package:html/dom.dart' as dom;

import '../models/epub_content_node.dart';
import 'computed_style.dart';
import 'css_parser.dart';
import 'css_selector_matcher.dart';
import 'css_specificity.dart';

const _inheritedProperties = {
  'color',
  'font-family',
  'font-size',
  'font-weight',
  'font-style',
  'font-variant',
  'line-height',
  'letter-spacing',
  'word-spacing',
  'text-align',
  'text-indent',
  'text-decoration',
  'text-transform',
  'visibility',
  'white-space',
};

class CssCascade {
  final List<CssRule> rules;
  final Map<dom.Element, ComputedStyle> _cache = {};

  CssCascade(this.rules);

  ComputedStyle resolve(dom.Element element) {
    return _cache.putIfAbsent(element, () => _resolve(element));
  }

  ComputedStyle _resolve(dom.Element element) {
    final matching = <_WeightedDeclaration>[];

    for (var i = 0; i < rules.length; i++) {
      final rule = rules[i];
      if (CssSelectorMatcher.matches(element, rule.selectorText)) {
        for (final entry in rule.declarations.entries) {
          final property = entry.key;
          final isImportant = property.endsWith('!important');
          final cleanProp = isImportant
              ? property.substring(0, property.length - 10)
              : property;
          matching.add(_WeightedDeclaration(
            property: cleanProp,
            value: entry.value,
            specificity: isImportant
                ? CssSpecificity(
                    id: rule.specificity.id,
                    cls: rule.specificity.cls,
                    type: rule.specificity.type,
                    important: true,
                  )
                : rule.specificity,
            sourceOrder: i,
          ));
        }
      }
    }

    // Inline styles have highest specificity
    final inlineStyle = element.attributes['style'] ?? '';
    if (inlineStyle.isNotEmpty) {
      final inlineRules = CssParser.parse('* { $inlineStyle }');
      for (final rule in inlineRules) {
        for (final entry in rule.declarations.entries) {
          matching.add(_WeightedDeclaration(
            property: entry.key,
            value: entry.value,
            specificity: CssSpecificity.inline,
            sourceOrder: 999999,
          ));
        }
      }
    }

    // Sort: !important > specificity > source order; last writer wins
    matching.sort((a, b) {
      final cmp = a.specificity.compareTo(b.specificity);
      if (cmp != 0) return cmp;
      return a.sourceOrder.compareTo(b.sourceOrder);
    });

    final declared = <String, String>{};
    for (final decl in matching) {
      declared[decl.property] = decl.value;
    }

    final parentStyle = element.parent is dom.Element
        ? resolve(element.parent as dom.Element)
        : null;

    final inherited = <String, String>{};
    if (parentStyle != null) {
      for (final prop in _inheritedProperties) {
        if (!declared.containsKey(prop)) {
          final parentVal = parentStyle.getValue(prop);
          if (parentVal != null) inherited[prop] = parentVal;
        }
      }
    }

    // Handle explicit 'inherit' keyword
    for (final entry in declared.entries) {
      if (entry.value == 'inherit' && parentStyle != null) {
        final parentVal = parentStyle.getValue(entry.key);
        if (parentVal != null) declared[entry.key] = parentVal;
      }
    }

    return ComputedStyle(
      declared: declared,
      inherited: inherited,
    );
  }

  Map<int, ComputedStyle> resolveAll(List<EpubContentNode> nodes) {
    final result = <int, ComputedStyle>{};
    _walkAndResolve(nodes, result);
    return result;
  }

  void _walkAndResolve(
    List<EpubContentNode> nodes,
    Map<int, ComputedStyle> out,
  ) {
    for (final node in nodes) {
      if (node.domElement != null && node.nodeId != null) {
        out[node.nodeId!] = resolve(node.domElement!);
      }
      switch (node) {
        case EpubParagraphNode n:
          _walkAndResolve(n.children, out);
        case EpubHeadingNode n:
          _walkAndResolve(n.children, out);
        case EpubListNode n:
          for (final item in n.items) { _walkAndResolve(item.children, out); }
        case EpubBlockquoteNode n:
          _walkAndResolve(n.children, out);
        case EpubAnchorNode n:
          if (n.child != null) _walkAndResolve([n.child!], out);
        default:
          break;
      }
    }
  }
}

class _WeightedDeclaration {
  final String property;
  final String value;
  final CssSpecificity specificity;
  final int sourceOrder;

  const _WeightedDeclaration({
    required this.property,
    required this.value,
    required this.specificity,
    required this.sourceOrder,
  });
}
