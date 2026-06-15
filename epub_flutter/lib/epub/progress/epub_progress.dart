class EpubProgress {
  final int bookId;
  final String cfi;
  final double percentage;
  final DateTime savedAt;

  const EpubProgress({
    required this.bookId,
    required this.cfi,
    required this.percentage,
    required this.savedAt,
  });
}
