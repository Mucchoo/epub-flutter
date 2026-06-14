import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../models/epub_toc_item.dart';
import 'path_utils.dart';

class NcxParser {
  static List<EpubTocItem> parse(List<int> bytes, String ncxHref) {
    final doc = XmlDocument.parse(utf8.decode(bytes));
    final ncxDir = p.posix.dirname(ncxHref);
    final effectiveDir = (ncxDir == '.' || ncxDir == '/') ? '' : ncxDir;
    final navMap = doc.findAllElements('navMap').firstOrNull;
    if (navMap == null) return [];
    return _parseNavPoints(navMap.findElements('navPoint'), effectiveDir);
  }

  static List<EpubTocItem> _parseNavPoints(
    Iterable<XmlElement> points,
    String dir,
  ) {
    return points.map((point) {
      final label =
          point.findAllElements('text').firstOrNull?.innerText.trim() ?? '';
      final rawSrc =
          point.findAllElements('content').firstOrNull?.getAttribute('src') ??
          '';
      final uri = Uri.parse(rawSrc);
      final resolved = dir.isEmpty
          ? normalizePath(uri.path)
          : normalizePath('$dir/${uri.path}');
      return EpubTocItem(
        title: label,
        href: resolved,
        fragment: uri.fragment.isEmpty ? null : uri.fragment,
        children: _parseNavPoints(point.findElements('navPoint'), dir),
      );
    }).toList();
  }
}
