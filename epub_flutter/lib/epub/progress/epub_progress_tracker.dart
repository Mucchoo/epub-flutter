import 'dart:async';

import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../screens/epub_reader/content_renderer.dart';
import '../models/epub_spine_item.dart';
import '../cfi/epub_cfi_generator.dart';
import 'epub_progress.dart';

class EpubProgressTracker {
  final int bookId;
  final List<EpubSpineItem> chapters;
  final ItemPositionsListener positionsListener;
  final Future<void> Function(EpubProgress progress) onSave;

  Timer? _debounce;
  final Map<int, List<NodeKey>> _chapterNodeKeys = {};

  EpubProgressTracker({
    required this.bookId,
    required this.chapters,
    required this.positionsListener,
    required this.onSave,
  });

  void start() {
    positionsListener.itemPositions.addListener(_onScroll);
  }

  void stop() {
    positionsListener.itemPositions.removeListener(_onScroll);
    _debounce?.cancel();
  }

  void updateChapterKeys(int spineIndex, List<NodeKey> keys) {
    _chapterNodeKeys[spineIndex] = keys;
  }

  double get currentPercentage {
    final positions = positionsListener.itemPositions.value;
    return _computePercentage(positions);
  }

  void _onScroll() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _save);
  }

  void _save() {
    final positions = positionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final cfi = EpubCfiGenerator.generate(
      chapters: chapters,
      positions: positions,
      chapterNodeKeys: _chapterNodeKeys,
    );
    if (cfi == null) return;

    final percentage = _computePercentage(positions);

    onSave(EpubProgress(
      bookId: bookId,
      cfi: cfi.toString(),
      percentage: percentage,
      savedAt: DateTime.now(),
    ));
  }

  double _computePercentage(Iterable<ItemPosition> positions) {
    if (positions.isEmpty || chapters.isEmpty) return 0.0;

    final topItem = positions
        .where((p) => p.itemTrailingEdge > 0)
        .fold<ItemPosition?>(
          null,
          (best, p) =>
              best == null || p.itemTrailingEdge < best.itemTrailingEdge
                  ? p
                  : best,
        );
    if (topItem == null) return 0.0;

    final withinItemProgress = topItem.itemLeadingEdge < 0
        ? (-topItem.itemLeadingEdge /
                (topItem.itemTrailingEdge - topItem.itemLeadingEdge))
            .clamp(0.0, 1.0)
        : 0.0;

    final baseProgress = topItem.index / chapters.length;
    final itemContribution = withinItemProgress / chapters.length;

    return (baseProgress + itemContribution).clamp(0.0, 1.0);
  }
}
