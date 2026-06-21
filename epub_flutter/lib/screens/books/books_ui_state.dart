import '../../data/models/book.dart';

class BooksUiState {
  const BooksUiState({
    this.books = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Book> books;
  final bool isLoading;
  final String? error;

  BooksUiState copyWith({
    List<Book>? books,
    bool? isLoading,
    String? error,
  }) => BooksUiState(
    books: books ?? this.books,
    isLoading: isLoading ?? this.isLoading,
    error: error ?? this.error,
  );
}
