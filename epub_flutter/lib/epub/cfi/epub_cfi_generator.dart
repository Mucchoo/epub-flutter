import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../screens/epub_reader/content_renderer.dart';
import '../models/epub_spine_item.dart';
import 'epub_cfi.dart';

class EpubCfiGenerator {
  static EpubCfi? generate({
    required List<EpubSpineItem> chapters,
    required Iterable<ItemPosition> positions,
    required Map<int, List<NodeKey>> chapterNodeKeys,
  }) {
    if (positions.isEmpty) return null;

    // Topmost chapter: smallest itemTrailingEdge that is > 0
    final topItem = positions
        .where((p) => p.itemTrailingEdge > 0)
        .fold<ItemPosition?>(
          null,
          (best, p) =>
              best == null || p.itemTrailingEdge < best.itemTrailingEdge
                  ? p
                  : best,
        );
    if (topItem == null) return null;

    final listIndex = topItem.index;
    if (listIndex >= chapters.length) return null;

    final cfiSpineIndex = (listIndex + 1) * 2;
    final itemrefId = chapters[listIndex].manifestItem.id;

    final nodeKeys = chapterNodeKeys[listIndex];
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
    // The node whose render box top is at or just above the viewport top (≤100px).
    // Among those, pick the one with the greatest dy (last one still in/above view).
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
