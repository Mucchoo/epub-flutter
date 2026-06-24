import '../models/highlight.dart';
import 'app_database.dart';

class HighlightDao {
  const HighlightDao(this._db);
  final AppDatabase _db;

  Future<int> insertHighlight(Highlight highlight) async {
    final db = await _db.database;
    return db.insert('highlights', highlight.toMap()..remove('id'));
  }

  Future<void> deleteHighlight(int id) async {
    final db = await _db.database;
    await db.delete('highlights', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateHighlight(
    int id,
    int startOffset,
    int endOffset,
  ) async {
    final db = await _db.database;
    await db.update(
      'highlights',
      {'start_offset': startOffset, 'end_offset': endOffset},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Highlight>> getHighlightsForBook(int bookId) async {
    final db = await _db.database;
    final rows = await db.query(
      'highlights',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    return rows.map(Highlight.fromMap).toList();
  }
}
