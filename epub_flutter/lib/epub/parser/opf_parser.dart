import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../models/epub_book.dart';
import '../models/epub_manifest_item.dart';
import '../models/epub_metadata.dart';
import '../models/epub_spine_item.dart';
import 'path_utils.dart';

class OpfParser {
  static EpubBook parse(Map<String, ArchiveFile> fileMap, String opfPath) {
    final opfDir = p.posix.dirname(opfPath);
    final effectiveOpfDir = (opfDir == '.' || opfDir == '/') ? '' : opfDir;

    final file = fileMap[opfPath];
    if (file == null) throw Exception('OPF file not found: $opfPath');
    final doc = XmlDocument.parse(utf8.decode(file.content as List<int>));

    final metadata = _parseMetadata(doc);
    final manifest = _parseManifest(doc, effectiveOpfDir);
    final (spine, tocId) = _parseSpine(doc, manifest);

    final navItem = manifest.values
        .where((m) => m.properties.contains('nav'))
        .firstOrNull;
    final ncxItem = tocId != null
        ? manifest[tocId]
        : manifest.values
              .where((m) => m.mediaType == 'application/x-dtbncx+xml')
              .firstOrNull;

    return EpubBook(
      metadata: metadata,
      manifest: manifest,
      spine: spine,
      fileMap: fileMap,
      navItem: navItem,
      ncxItem: ncxItem,
      opfDir: effectiveOpfDir,
    );
  }

  static EpubMetadata _parseMetadata(XmlDocument doc) {
    String? findText(String tag) {
      return doc.findAllElements(tag).firstOrNull?.innerText.trim();
    }

    return EpubMetadata(
      title: findText('dc:title') ?? findText('title'),
      creator: findText('dc:creator') ?? findText('creator'),
      language: findText('dc:language') ?? findText('language'),
      identifier: findText('dc:identifier') ?? findText('identifier'),
    );
  }

  static Map<String, EpubManifestItem> _parseManifest(
    XmlDocument doc,
    String opfDir,
  ) {
    final manifest = <String, EpubManifestItem>{};
    for (final item in doc.findAllElements('item')) {
      final id = item.getAttribute('id');
      final rawHref = item.getAttribute('href');
      if (id == null || rawHref == null || id.isEmpty || rawHref.isEmpty) {
        continue;
      }
      final decodedHref = Uri.decodeFull(rawHref);
      final resolvedHref = opfDir.isEmpty
          ? normalizePath(decodedHref)
          : normalizePath('$opfDir/$decodedHref');

      manifest[id] = EpubManifestItem(
        id: id,
        href: resolvedHref,
        mediaType: item.getAttribute('media-type') ?? '',
        properties: item.getAttribute('properties') ?? '',
      );
    }
    return manifest;
  }

  static (List<EpubSpineItem>, String?) _parseSpine(
    XmlDocument doc,
    Map<String, EpubManifestItem> manifest,
  ) {
    final spineElement = doc.findAllElements('spine').firstOrNull;
    if (spineElement == null) return ([], null);

    final tocId = spineElement.getAttribute('toc');
    final spine = <EpubSpineItem>[];
    for (final ref in spineElement.findAllElements('itemref')) {
      final idref = ref.getAttribute('idref');
      if (idref == null) continue;
      final linear = ref.getAttribute('linear') != 'no';
      final manifestItem = manifest[idref];
      if (manifestItem != null) {
        spine.add(EpubSpineItem(manifestItem: manifestItem, linear: linear));
      }
    }
    return (spine, tocId);
  }
}
