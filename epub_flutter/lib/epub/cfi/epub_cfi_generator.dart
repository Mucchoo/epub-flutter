import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../models/epub_spine_item.dart';
import 'epub_cfi.dart';
import 'node_key.dart';

class EpubCfiGenerator {
  static EpubCfi? generate({
    required List<EpubSpineItem> chapters,
    required int currentChapterIndex,
    required Map<int, List<NodeKey>> chapterNodeKeys,
  }) {
    if (currentChapterIndex < 0 || currentChapterIndex >= chapters.length) {
      return null;
    }

    final cfiSpineIndex = (currentChapterIndex + 1) * 2;
    final itemrefId = chapters[currentChapterIndex].manifestItem.id;

    final nodeKeys = chapterNodeKeys[currentChapterIndex];
    if (nodeKeys == null || nodeKeys.isEmpty) {
      return EpubCfi(
        spineIndex: cfiSpineIndex,
        spineIdAssertion: itemrefId,
        contentSteps: [],
      );
    }

    final topNode = _findTopmostVisibleNode(nodeKeys);
    if (topNode == null) {
      return EpubCfi(
        spineIndex: cfiSpineIndex,
        spineIdAssertion: itemrefId,
        contentSteps: [],
      );
    }

    return EpubCfi(
      spineIndex: cfiSpineIndex,
      spineIdAssertion: itemrefId,
      contentSteps: [topNode.domIndex],
      targetIdAssertion: topNode.elementId,
    );
  }

  static NodeKey? _findTopmostVisibleNode(List<NodeKey> nodeKeys) {
    double? bestY;
    NodeKey? best;

    for (final node in nodeKeys) {
      final ctx = node.key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final y = box.localToGlobal(Offset.zero).dy;

      if (y <= 100) {
        if (bestY == null || y > bestY) {
          bestY = y;
          best = node;
        }
      }
    }

    return best ?? nodeKeys.firstOrNull;
  }
}
