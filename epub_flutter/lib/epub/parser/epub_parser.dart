import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/epub_book.dart';
import 'container_parser.dart';
import 'epub_parse_exception.dart';
import 'opf_parser.dart';
import 'path_utils.dart';

class EpubParser {
  static Future<EpubBook> parse(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return parseBytes(bytes);
  }

  static EpubBook parseBytes(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    final fileMap = <String, ArchiveFile>{};
    for (final file in archive.files) {
      if (file.isFile) {
        fileMap[normalizePath(file.name)] = file;
      }
    }

    _validateMimetype(fileMap);

    final opfPath = ContainerParser.parse(fileMap);
    return OpfParser.parse(fileMap, opfPath);
  }

  static void _validateMimetype(Map<String, ArchiveFile> fileMap) {
    final mimeFile = fileMap['mimetype'];
    if (mimeFile == null) return;
    final content = String.fromCharCodes(mimeFile.content as List<int>).trim();
    if (content != 'application/epub+zip') {
      throw EpubParseException('Invalid mimetype: $content');
    }
  }
}
