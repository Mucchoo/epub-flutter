import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'epub_parse_exception.dart';
import 'path_utils.dart';

class ContainerParser {
  static String parse(Map<String, ArchiveFile> fileMap) {
    final file = fileMap['META-INF/container.xml'];
    if (file == null) throw EpubParseException('container.xml not found');

    final doc = XmlDocument.parse(utf8.decode(file.content as List<int>));
    final rootfile = doc.findAllElements('rootfile').firstOrNull;
    if (rootfile == null) throw EpubParseException('No rootfile in container.xml');

    final fullPath = rootfile.getAttribute('full-path');
    if (fullPath == null || fullPath.isEmpty) {
      throw EpubParseException('rootfile missing full-path');
    }
    return normalizePath(fullPath);
  }
}
