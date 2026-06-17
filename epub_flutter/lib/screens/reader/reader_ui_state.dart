import '../../epub/models/epub_book.dart';
import '../../epub/models/epub_content_node.dart';
import '../../epub/models/epub_spine_item.dart';
import '../../epub/styling/computed_style.dart';

typedef ChapterData = ({
  List<EpubContentNode> nodes,
  Map<int, ComputedStyle> styleMap,
});

class ReaderUiState {
  const ReaderUiState({
    this.book,
    this.error,
    this.chapters = const [],
    this.chapterData = const [],
    this.isRestoring = true,
    this.progressPercentage = 0.0,
  });

  final EpubBook? book;
  final String? error;
  final List<EpubSpineItem> chapters;
  final List<ChapterData?> chapterData;
  final bool isRestoring;
  final double progressPercentage;

  ReaderUiState copyWith({
    EpubBook? book,
    String? error,
    List<EpubSpineItem>? chapters,
    List<ChapterData?>? chapterData,
    bool? isRestoring,
    double? progressPercentage,
  }) => ReaderUiState(
    book: book ?? this.book,
    error: error ?? this.error,
    chapters: chapters ?? this.chapters,
    chapterData: chapterData ?? this.chapterData,
    isRestoring: isRestoring ?? this.isRestoring,
    progressPercentage: progressPercentage ?? this.progressPercentage,
  );
}
