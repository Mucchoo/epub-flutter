import 'package:flutter/widgets.dart';

import '../../screens/epub_reader/content_renderer.dart';
import '../models/epub_spine_item.dart';
import 'epub_cfi.dart';

class ResolvedPosition {
  final int spineIndex;
  final GlobalKey? nodeKey;
  const ResolvedPosition({required this.spineIndex, this.nodeKey});
}

class EpubCfiResolver {
  static ResolvedPosition? resolve({
    required EpubCfi cfi,
    required List<EpubSpineItem> chapters,
    required Map<int, List<NodeKey>> chapterNodeKeys,
  }) {
    final listIndex = (cfi.spineIndex ~/ 2) - 1;
    if (listIndex < 0 || listIndex >= chapters.length) return null;

    final correctedIndex = _correctSpineIndex(cfi, chapters, listIndex);

    if (cfi.contentSteps.isEmpty) {
      return ResolvedPosition(spineIndex: correctedIndex, nodeKey: null);
    }

    final targetDomIndex = cfi.contentSteps.last;
    final keys = chapterNodeKeys[correctedIndex];

    GlobalKey? targetKey;
    if (keys != null) {
      if (cfi.targetIdAssertion != null) {
        targetKey = keys
            .where((k) => k.elementId == cfi.targetIdAssertion)
            .firstOrNull
            ?.key;
      }
      if (targetKey == null) {
        targetKey = keys.where((k) => k.domIndex == targetDomIndex).firstOrNull?.key;
      }
      if (targetKey == null) {
        targetKey = keys.where((k) => k.domIndex <= targetDomIndex).lastOrNull?.key;
      }
    }

    return ResolvedPosition(spineIndex: correctedIndex, nodeKey: targetKey);
  }

  static int _correctSpineIndex(
    EpubCfi cfi,
    List<EpubSpineItem> chapters,
    int guessedIndex,
  ) {
    if (cfi.spineIdAssertion == null) return guessedIndex;
    if (chapters[guessedIndex].manifestItem.id == cfi.spineIdAssertion) {
      return guessedIndex;
    }
    final corrected = chapters.indexWhere(
      (s) => s.manifestItem.id == cfi.spineIdAssertion,
    );
    return corrected >= 0 ? corrected : guessedIndex;
  }
}
