import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;

import '../models/epub_toc_item.dart';
import 'path_utils.dart';

class NavParser {
  static List<EpubTocItem> parse(List<int> bytes, String navHref) {
    final doc = html_parser.parse(utf8.decode(bytes));
    final navDir = p.posix.dirname(navHref);
    final effectiveNavDir = (navDir == '.' || navDir == '/') ? '' : navDir;

    final navElements = doc.querySelectorAll('nav');
    if (navElements.isEmpty) return [];

    final tocNav = navElements.firstWhere(
      (el) =>
          (el.attributes['epub:type'] ?? el.attributes['type'] ?? '').contains(
            'toc',
          ),
      orElse: () => navElements.first,
    );

    return _parseOlItems(tocNav.querySelector('ol'), effectiveNavDir);
  }

  static List<EpubTocItem> _parseOlItems(dom.Element? ol, String navDir) {
    if (ol == null) return [];
    final items = <EpubTocItem>[];
    for (final li in ol.children.where((c) => c.localName == 'li')) {
      final a = li.querySelector('a');
      if (a == null) continue;
      final rawHref = a.attributes['href'] ?? '';
      final uri = Uri.parse(rawHref);
      final resolved = navDir.isEmpty
          ? normalizePath(uri.path)
          : normalizePath('$navDir/${uri.path}');
      items.add(EpubTocItem(
        title: a.text.trim(),
        href: resolved,
        fragment: uri.fragment.isEmpty ? null : uri.fragment,
        children: _parseOlItems(li.querySelector('ol'), navDir),
      ));
    }
    return items;
  }
}
