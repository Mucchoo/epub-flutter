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

  Future<void> saveReadingPosition(int id, int offset) async {
    final db = await _db.database;
    await db.update(
      'books',
      {'reading_offset': offset},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int?> getReadingPosition(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'books',
      columns: ['reading_offset'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['reading_offset'] as int?;
  }
}