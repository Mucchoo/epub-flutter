class Book {
  const Book({
    required this.id,
    required this.title,
    this.author,
    required this.progress,
    this.coverImagePath,
    required this.filePath,
  });

  final int id;
  final String title;
  final String? author;
  final double progress;
  final String? coverImagePath;
  final String filePath;

  Book copyWith({double? progress}) => Book(
        id: id,
        title: title,
        author: author,
        progress: progress ?? this.progress,
        coverImagePath: coverImagePath,
        filePath: filePath,
      );

  Map<String, Object?> toMap() => {
        'title': title,
        'author': author,
        'progress': progress,
        'cover_image_path': coverImagePath,
        'file_path': filePath,
      };

  factory Book.fromMap(Map<String, Object?> map) => Book(
        id: map['id'] as int,
        title: map['title'] as String,
        author: map['author'] as String?,
        progress: (map['progress'] as num).toDouble(),
        coverImagePath: map['cover_image_path'] as String?,
        filePath: map['file_path'] as String,
      );
}
