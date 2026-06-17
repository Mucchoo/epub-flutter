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
    final count = await db.update(
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
    final cfi = rows.isEmpty ? null : rows.first['cfi'] as String?;
    return cfi;
  }

  Future<void> saveScrollPosition(int id, int index, double alignment) async {
    final db = await _db.database;
    await db.update(
      'books',
      {'scroll_index': index, 'scroll_alignment': alignment},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<({int index, double alignment})?> getScrollPosition(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'books',
      columns: ['scroll_index', 'scroll_alignment'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final idx = rows.first['scroll_index'] as int?;
    final align = rows.first['scroll_alignment'] as double?;
    if (idx == null || align == null) return null;
    return (index: idx, alignment: align);
  }
}
