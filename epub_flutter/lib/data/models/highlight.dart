class Highlight {
  const Highlight({
    this.id,
    required this.bookId,
    required this.chapter,
    required this.text,
  });

  final int? id;
  final int bookId;
  final int chapter;
  final String text;

  Map<String, Object?> toMap() => {
        'id': id,
        'book_id': bookId,
        'chapter': chapter,
        'text': text,
      };

  static Highlight fromMap(Map<String, Object?> map) => Highlight(
        id: map['id'] as int?,
        bookId: map['book_id'] as int,
        chapter: map['chapter'] as int,
        text: map['text'] as String,
      );
}
