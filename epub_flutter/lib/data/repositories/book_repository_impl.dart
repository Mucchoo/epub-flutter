import '../local/book_dao.dart';
import '../models/book.dart';
import 'book_repository.dart';

class BookRepositoryImpl implements BookRepository {
  const BookRepositoryImpl(this._dao);
  final BookDao _dao;

  @override
  Future<List<Book>> getBooks() => _dao.getAllBooks();

  @override
  Future<Book> addBook({
    required String filePath,
    required String title,
    String? author,
    String? coverImagePath,
  }) async {
    final book = Book(
      id: 0,
      title: title,
      author: author,
      progress: 0.0,
      coverImagePath: coverImagePath,
      filePath: filePath,
    );
    final id = await _dao.insertBook(book);
    return Book(
      id: id,
      title: title,
      author: author,
      progress: 0.0,
      coverImagePath: coverImagePath,
      filePath: filePath,
    );
  }

  @override
  Future<void> updateProgress(int id, double progress) =>
      _dao.updateProgress(id, progress);

  @override
  Future<void> deleteBook(int id) => _dao.deleteBook(id);
}
