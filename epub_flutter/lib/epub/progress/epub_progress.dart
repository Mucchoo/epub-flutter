class EpubProgress {
  final int bookId;
  final String cfi;
  final double percentage;
  final DateTime savedAt;
  final int scrollIndex;
  final double scrollAlignment;

  const EpubProgress({
    required this.bookId,
    required this.cfi,
    required this.percentage,
    required this.savedAt,
    required this.scrollIndex,
    required this.scrollAlignment,
  });
}
