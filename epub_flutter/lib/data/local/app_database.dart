import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'epub_reader.db'),
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE books (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          title           TEXT    NOT NULL,
          author          TEXT,
          progress        REAL    NOT NULL DEFAULT 0.0,
          cover_image_path TEXT,
          file_path       TEXT    NOT NULL
        )
      '''),
    );
  }
}
