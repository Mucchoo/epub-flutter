import '../models/book.dart';

abstract interface class BookRepository {
  Future<List<Book>> getBooks();
  Future<Book> addBook({
    required String filePath,
    required String title,
    String? author,
    String? coverImagePath,
  });
  Future<void> updateProgress(int id, double progress);
  Future<void> saveCfi(int id, String cfi);
  Future<String?> getCfi(int id);
  Future<void> deleteBook(int id);
}
