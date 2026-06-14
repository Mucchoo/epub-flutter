import 'dart:io';

import 'package:archive/archive.dart';

import '../models/epub_book.dart';
import '../models/epub_toc_item.dart';
import 'container_parser.dart';
import 'epub_parse_exception.dart';
import 'nav_parser.dart';
import 'ncx_parser.dart';
import 'opf_parser.dart';
import 'path_utils.dart';

class EpubParser {
  static Future<EpubBook> parse(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final fileMap = <String, ArchiveFile>{};
    for (final file in archive.files) {
      if (file.isFile) {
        fileMap[normalizePath(file.name)] = file;
      }
    }

    _validateMimetype(fileMap);

    final opfPath = ContainerParser.parse(fileMap);
    final book = OpfParser.parse(fileMap, opfPath);
    book.toc = _parseToc(book, fileMap);

    return book;
  }

  static void _validateMimetype(Map<String, ArchiveFile> fileMap) {
    final mimeFile = fileMap['mimetype'];
    if (mimeFile == null) return;
    final content = String.fromCharCodes(mimeFile.content as List<int>).trim();
    if (content != 'application/epub+zip') {
      throw EpubParseException('Invalid mimetype: $content');
    }
  }

  static List<EpubTocItem> _parseToc(
    EpubBook book,
    Map<String, ArchiveFile> fileMap,
  ) {
    List<EpubTocItem> toc = [];

    if (book.navItem != null) {
      final navFile = fileMap[book.navItem!.href];
      if (navFile != null) {
        try {
          toc = NavParser.parse(navFile.content as List<int>, book.navItem!.href);
        } catch (_) {}
      }
    }

    if (toc.isEmpty && book.ncxItem != null) {
      final ncxFile = fileMap[book.ncxItem!.href];
      if (ncxFile != null) {
        try {
          toc = NcxParser.parse(ncxFile.content as List<int>, book.ncxItem!.href);
        } catch (_) {}
      }
    }

    // Fallback: synthesize from spine
    if (toc.isEmpty) {
      toc = book.spine
          .where((s) => s.linear)
          .map((s) => EpubTocItem(title: s.manifestItem.id, href: s.manifestItem.href))
          .toList();
    }

    return _reconcile(toc, fileMap);
  }

  static List<EpubTocItem> _reconcile(
    List<EpubTocItem> toc,
    Map<String, ArchiveFile> fileMap,
  ) {
    return toc
        .where((item) => fileMap.containsKey(item.href))
        .map((item) => item.copyWith(children: _reconcile(item.children, fileMap)))
        .toList();
  }
}
