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

  Future<void> saveCfi(int id, String cfi) async {
    final db = await _db.database;
    await db.update(
      'books',
      {'cfi': cfi},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String?> getCfi(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'books',
      columns: ['cfi'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['cfi'] as String?;
  }
}
