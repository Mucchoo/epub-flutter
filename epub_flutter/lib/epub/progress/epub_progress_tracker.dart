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

  // chapterWeights[i] = fraction of total book text in chapter i (sums to 1.0).
  // chapterOffsets[i] = cumulative weight of all chapters before i.
  final List<double> _chapterWeights;
  final List<double> _chapterOffsets;

  Timer? _debounce;
  final Map<int, List<NodeKey>> _chapterNodeKeys = {};

  EpubProgressTracker({
    required this.bookId,
    required this.chapters,
    required this.positionsListener,
    required this.onSave,
    List<double>? chapterWeights,
  })  : _chapterWeights = chapterWeights ?? _uniformWeights(chapters.length),
        _chapterOffsets = _buildOffsets(
          chapterWeights ?? _uniformWeights(chapters.length),
        );

  static List<double> _uniformWeights(int n) =>
      n == 0 ? [] : List.filled(n, 1.0 / n);

  static List<double> _buildOffsets(List<double> weights) {
    final offsets = List<double>.filled(weights.length, 0.0);
    for (var i = 1; i < weights.length; i++) {
      offsets[i] = offsets[i - 1] + weights[i - 1];
    }
    return offsets;
  }

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

    final itemSpan = topItem.itemTrailingEdge - topItem.itemLeadingEdge;
    final withinItemProgress = itemSpan > 0
        ? (-topItem.itemLeadingEdge / itemSpan).clamp(0.0, 1.0)
        : 0.0;

    final i = topItem.index.clamp(0, _chapterWeights.length - 1);
    final baseProgress = _chapterOffsets[i];
    final itemContribution = withinItemProgress * _chapterWeights[i];

    return (baseProgress + itemContribution).clamp(0.0, 1.0);
  }
}
