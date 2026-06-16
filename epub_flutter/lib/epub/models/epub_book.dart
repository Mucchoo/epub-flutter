import 'package:archive/archive.dart';

import 'epub_content_node.dart';
import 'epub_manifest_item.dart';
import 'epub_metadata.dart';
import 'epub_spine_item.dart';
import 'epub_toc_item.dart';
import '../parser/content_parser.dart';

class EpubBook {
  final EpubMetadata metadata;
  final Map<String, EpubManifestItem> manifest;
  final List<EpubSpineItem> spine;
  final Map<String, ArchiveFile> fileMap;
  final EpubManifestItem? navItem;
  final EpubManifestItem? ncxItem;
  final String opfDir;
  List<EpubTocItem> toc;

  final _contentCache = <int, List<EpubContentNode>>{};

  EpubBook({
    required this.metadata,
    required this.manifest,
    required this.spine,
    required this.fileMap,
    required this.opfDir,
    this.navItem,
    this.ncxItem,
    this.toc = const [],
  });

  List<EpubContentNode> getChapterContent(int spineIndex) {
    return _contentCache.putIfAbsent(spineIndex, () {
      final item = spine[spineIndex];
      final file = fileMap[item.manifestItem.href];
      if (file == null) return [];
      return ContentParser(
        chapterHref: item.manifestItem.href,
        fileMap: fileMap,
        knownFilePaths: fileMap.keys.toSet(),
      ).parse(file.content as List<int>);
    });
  }
}
