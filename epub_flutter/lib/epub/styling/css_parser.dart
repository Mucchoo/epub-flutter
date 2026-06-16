import 'package:csslib/parser.dart' as css;
import 'package:csslib/visitor.dart';

import 'css_specificity.dart';

class CssRule {
  final String selectorText;
  final Map<String, String> declarations;
  final String sourceHref;
  late final CssSpecificity specificity;

  CssRule({
    required this.selectorText,
    required this.declarations,
    required this.sourceHref,
  }) {
    specificity = CssSpecificity.fromSelector(selectorText);
  }
}

class FontFaceDeclaration {
  final String family;
  final String src;
  final String weight;
  final String style;

  const FontFaceDeclaration({
    required this.family,
    required this.src,
    required this.weight,
    required this.style,
  });
}

class CssParser {
  static List<CssRule> parse(String cssText, {String sourceHref = ''}) {
    final errors = <css.Message>[];
    StyleSheet stylesheet;
    try {
      stylesheet = css.parse(
        cssText,
        errors: errors,
        options: const css.PreprocessorOptions(
          useColors: false,
          checked: false,
        ),
      );
    } catch (_) {
      return [];
    }

    final rules = <CssRule>[];
    for (final node in stylesheet.topLevels) {
      if (node is RuleSet) {
        final declarations = _extractDeclarations(node.declarationGroup);
        if (declarations.isEmpty) continue;
        for (final selector in node.selectorGroup?.selectors ?? <Selector>[]) {
          final selectorText = _nodeToString(selector).trim();
          if (selectorText.isEmpty) continue;
          rules.add(CssRule(
            selectorText: selectorText,
            declarations: declarations,
            sourceHref: sourceHref,
          ));
        }
      }
      // @font-face is parsed separately via parseFontFaces()
      // @media and @supports are skipped
    }
    return rules;
  }

  // Regex-based @font-face extraction — csslib 0.17.x does not export FontFace
  static List<FontFaceDeclaration> parseFontFaces(String cssText) {
    final result = <FontFaceDeclaration>[];
    final blockRe = RegExp(
      r'@font-face\s*\{([^}]*)\}',
      caseSensitive: false,
      dotAll: true,
    );
    final propRe = RegExp(r'([\w-]+)\s*:\s*([^;]+)');

    for (final m in blockRe.allMatches(cssText)) {
      final block = m.group(1) ?? '';
      final props = <String, String>{};
      for (final p in propRe.allMatches(block)) {
        props[p.group(1)!.trim().toLowerCase()] = p.group(2)!.trim();
      }
      final family = _unquote(props['font-family'] ?? '');
      final src = props['src'] ?? '';
      if (family.isEmpty || src.isEmpty) continue;
      result.add(FontFaceDeclaration(
        family: family,
        src: src,
        weight: props['font-weight'] ?? 'normal',
        style: props['font-style'] ?? 'normal',
      ));
    }
    return result;
  }

  static Map<String, String> _extractDeclarations(DeclarationGroup group) {
    final result = <String, String>{};
    for (final node in group.declarations) {
      if (node is! Declaration) continue;
      final property = node.property.toLowerCase().trim();
      if (property.isEmpty || node.expression == null) continue;
      final value = _expressionToString(node.expression!).trim();
      if (value.isEmpty) continue;
      if (node.important) {
        result['$property!important'] = value;
      } else {
        result[property] = value;
      }
    }
    return result;
  }

  static String _expressionToString(Expression expr) {
    final printer = CssPrinter();
    expr.visit(printer);
    return printer.toString();
  }

  static String _nodeToString(TreeNode node) {
    final printer = CssPrinter();
    node.visit(printer);
    return printer.toString();
  }

  static String _unquote(String s) =>
      s.replaceAll(RegExp(r"""^['"]|['"]$"""), '').trim();
}
