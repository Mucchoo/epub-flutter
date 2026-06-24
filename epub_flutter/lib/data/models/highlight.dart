class Highlight {
  const Highlight({
    this.id,
    required this.bookId,
    required this.startOffset,
    required this.endOffset,
  });

  final int? id;
  final int bookId;
  final int startOffset;
  final int endOffset;

  Map<String, Object?> toMap() => {
        'id': id,
        'book_id': bookId,
        'start_offset': startOffset,
        'end_offset': endOffset,
      };

  static Highlight fromMap(Map<String, Object?> map) => Highlight(
        id: map['id'] as int?,
        bookId: map['book_id'] as int,
        startOffset: map['start_offset'] as int,
        endOffset: map['end_offset'] as int,
      );
}
