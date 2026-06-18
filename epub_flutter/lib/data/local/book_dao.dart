import '../models/book.dart';
import 'app_database.dart';

class BookDao {
  const BookDao(this._db);
  final AppDatabase _db;

  Future<List<Book>> getAllBooks() async {
    final db = await _db.database;
    final rows = await db.query('books', orderBy: 'id ASC');
    return rows.map(Book.fromMap).toList();
  }

  Future<int> insertBook(Book book) async {
    final db = await _db.database;
    return db.insert('books', book.toMap());
  }

  Future<void> updateProgress(int id, double progress) async {
    final db = await _db.database;
    await db.update(
      'books',
      {'progress': progress},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteBook(int id) async {
    final db = await _db.database;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveReadingPosition(
    int id,
    int chapter,
    String snippet,
  ) async {
    final db = await _db.database;
    await db.update(
      'books',
      {'reading_chapter': chapter, 'reading_snippet': snippet},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<({int chapter, String snippet})?> getReadingPosition(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'books',
      columns: ['reading_chapter', 'reading_snippet'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final chapter = row['reading_chapter'] as int?;
    final snippet = row['reading_snippet'] as String?;
    if (chapter == null || snippet == null) return null;
    return (chapter: chapter, snippet: snippet);
  }
}