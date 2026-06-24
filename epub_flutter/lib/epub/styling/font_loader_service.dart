import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'css_parser.dart';
import '../parser/path_utils.dart';

class FontLoaderService {
  final Map<String, ArchiveFile> fileMap;
  final String opfDir;
  final _loaded = <String>{};

  FontLoaderService({required this.fileMap, required this.opfDir});

  Future<void> loadFontsFromStylesheet(String cssText, String cssHref) async {
    final fontFaces = CssParser.parseFontFaces(cssText);
    for (final face in fontFaces) {
      await _loadFontFace(face, cssHref);
    }
  }

  Future<void> _loadFontFace(FontFaceDeclaration face, String cssHref) async {
    final key = '${face.family}_${face.weight}_${face.style}';
    if (_loaded.contains(key)) return;

    final srcMatch = RegExp(
      r"""url\(['"]?([^'")\s]+)['"]?\)""",
    ).firstMatch(face.src);
    if (srcMatch == null) return;

    final rawPath = srcMatch.group(1)!;
    final cssDir = p.posix.dirname(cssHref);
    final resolvedPath = normalizePath(
      cssDir.isEmpty || cssDir == '.' ? rawPath : '$cssDir/$rawPath',
    );

    final file = fileMap[resolvedPath];
    if (file == null) return;

    final ext = p.extension(resolvedPath).toLowerCase();
    if (ext != '.ttf' && ext != '.otf') {
      // WOFF/WOFF2 not supported by Flutter's FontLoader — skip silently
      return;
    }

    try {
      final bytes = Uint8List.fromList(file.content as List<int>);
      final loader = FontLoader(face.family);
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
      _loaded.add(key);
    } catch (e) {
      debugPrint('Failed to load font ${face.family}: $e');
    }
  }
}
