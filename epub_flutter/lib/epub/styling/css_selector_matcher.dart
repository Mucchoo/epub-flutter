import 'package:html/dom.dart' as dom;

class CssSelectorMatcher {
  static bool matches(dom.Element element, String selectorText) {
    return _matchesComplex(element, selectorText.trim());
  }

  static bool _matchesComplex(dom.Element el, String selector) {
    if (selector.contains(' > ')) {
      final idx = selector.lastIndexOf(' > ');
      final parentSel = selector.substring(0, idx).trim();
      final selfSel = selector.substring(idx + 3).trim();
      return _matchesSimple(el, selfSel) &&
          el.parent is dom.Element &&
          _matchesComplex(el.parent as dom.Element, parentSel);
    }

    if (selector.contains(' + ')) {
      final idx = selector.lastIndexOf(' + ');
      final sibSel = selector.substring(0, idx).trim();
      final selfSel = selector.substring(idx + 3).trim();
      final prev = _previousElementSibling(el);
      return _matchesSimple(el, selfSel) &&
          prev != null &&
          _matchesComplex(prev, sibSel);
    }

    if (selector.contains(' ')) {
      final idx = selector.lastIndexOf(' ');
      final ancestorSel = selector.substring(0, idx).trim();
      final selfSel = selector.substring(idx + 1).trim();
      if (!_matchesSimple(el, selfSel)) return false;
      dom.Node? node = el.parent;
      while (node != null) {
        if (node is dom.Element && _matchesComplex(node, ancestorSel)) {
          return true;
        }
        node = node.parent;
      }
      return false;
    }

    return _matchesSimple(el, selector);
  }

  static bool _matchesSimple(dom.Element el, String selector) {
    String remaining = selector;

    final typeMatch = RegExp(r'^([a-zA-Z][\w-]*)').firstMatch(remaining);
    if (typeMatch != null) {
      final type = typeMatch.group(1)!.toLowerCase();
      if (type != '*' && el.localName?.toLowerCase() != type) return false;
      remaining = remaining.substring(typeMatch.end);
    }

    while (remaining.isNotEmpty) {
      if (remaining.startsWith('#')) {
        final m = RegExp(r'^#([\w-]+)').firstMatch(remaining);
        if (m == null) return false;
        if (el.id != m.group(1)) return false;
        remaining = remaining.substring(m.end);
      } else if (remaining.startsWith('.')) {
        final m = RegExp(r'^\.([\w-]+)').firstMatch(remaining);
        if (m == null) return false;
        if (!el.classes.contains(m.group(1))) return false;
        remaining = remaining.substring(m.end);
      } else if (remaining.startsWith('[')) {
        final m = RegExp(r'^\[([^\]]+)\]').firstMatch(remaining);
        if (m == null) return false;
        if (!_matchesAttributeSelector(el, m.group(1)!)) return false;
        remaining = remaining.substring(m.end);
      } else if (remaining.startsWith(':')) {
        final m =
            RegExp(r'^:([\w-]+)(?:\(([^)]*)\))?').firstMatch(remaining);
        if (m == null) return false;
        if (!_matchesPseudoClass(el, m.group(1)!, m.group(2))) return false;
        remaining = remaining.substring(m.end);
      } else {
        break;
      }
    }
    return true;
  }

  static bool _matchesAttributeSelector(dom.Element el, String expr) {
    final m = RegExp(r'^([\w-]+)(?:([~|^$*]?=)"?([^"]*)"?)?$')
        .firstMatch(expr.trim());
    if (m == null) return el.attributes.containsKey(expr.trim());
    final attrName = m.group(1)!;
    final op = m.group(2) ?? '';
    final val = m.group(3) ?? '';
    final attrVal = el.attributes[attrName] ?? '';
    return switch (op) {
      '' => el.attributes.containsKey(attrName),
      '=' => attrVal == val,
      '~=' => attrVal.split(' ').contains(val),
      '^=' => attrVal.startsWith(val),
      r'$=' => attrVal.endsWith(val),
      '*=' => attrVal.contains(val),
      _ => false,
    };
  }

  static bool _matchesPseudoClass(
    dom.Element el,
    String pseudo,
    String? arg,
  ) {
    return switch (pseudo) {
      'first-child' => _previousElementSibling(el) == null,
      'last-child' => _nextElementSibling(el) == null,
      'nth-child' => _matchesNthChild(el, arg ?? ''),
      'first-of-type' => _isFirstOfType(el),
      'last-of-type' => _isLastOfType(el),
      'not' => arg != null && !_matchesSimple(el, arg),
      _ => false, // :hover, :focus, etc. — always false in a reader
    };
  }

  static bool _matchesNthChild(dom.Element el, String arg) {
    final siblings = (el.parent?.children ?? [])
        .whereType<dom.Element>()
        .toList();
    final index = siblings.indexOf(el) + 1;
    if (arg == 'odd') return index % 2 == 1;
    if (arg == 'even') return index % 2 == 0;
    final simple = int.tryParse(arg);
    if (simple != null) return index == simple;
    final m = RegExp(r'^(-?\d*)n(?:\+(-?\d+))?$').firstMatch(arg);
    if (m != null) {
      final a =
          int.tryParse(m.group(1)!.isEmpty ? '1' : m.group(1)!) ?? 1;
      final b = int.tryParse(m.group(2) ?? '0') ?? 0;
      if (a == 0) return index == b;
      return (index - b) % a == 0 && (index - b) ~/ a >= 0;
    }
    return false;
  }

  static dom.Element? _previousElementSibling(dom.Element el) {
    final parent = el.parent;
    if (parent == null) return null;
    dom.Element? prev;
    for (final child in parent.children) {
      if (child == el) return prev;
      prev = child;
    }
    return null;
  }

  static dom.Element? _nextElementSibling(dom.Element el) {
    final parent = el.parent;
    if (parent == null) return null;
    bool found = false;
    for (final child in parent.children) {
      if (found) return child;
      if (child == el) found = true;
    }
    return null;
  }

  static bool _isFirstOfType(dom.Element el) {
    final tag = el.localName;
    for (final sib in el.parent?.children ?? []) {
      if (sib.localName == tag) return sib == el;
    }
    return false;
  }

  static bool _isLastOfType(dom.Element el) {
    final tag = el.localName;
    dom.Element? last;
    for (final sib in el.parent?.children ?? []) {
      if (sib.localName == tag) last = sib;
    }
    return last == el;
  }
}
