import 'package:epub_flutter/data/models/book.dart';
import 'package:epub_flutter/data/repositories/book_repository.dart';
import 'package:epub_flutter/screens/books/books_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBookRepository extends Mock implements BookRepository {}

const _book1 = Book(id: 1, title: 'Dune', progress: 0.0, filePath: '/books/dune.epub');
const _bookA = Book(id: 1, title: 'A', progress: 0.0, filePath: '/a.epub');
const _bookB = Book(id: 2, title: 'B', progress: 0.5, filePath: '/b.epub');
const _bookC = Book(id: 3, title: 'C', progress: 1.0, filePath: '/c.epub');

void main() {
  group('BooksViewModel', () {
    late MockBookRepository repository;
    late BooksViewModel viewModel;

    setUp(() {
      repository = MockBookRepository();
      viewModel = BooksViewModel(repository);
    });

    tearDown(() => viewModel.dispose());

    test('initial state has empty books, no error, and is not loading', () {
      expect(viewModel.state.books, isEmpty);
      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.error, isNull);
    });

    test('loadBooks populates books on success', () async {
      when(() => repository.getBooks()).thenAnswer((_) async => [_book1]);

      await viewModel.loadBooks();

      expect(viewModel.state.books, hasLength(1));
      expect(viewModel.state.books.first.title, 'Dune');
      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.error, isNull);
    });

    test('loadBooks sets error on failure', () async {
      when(() => repository.getBooks()).thenThrow(Exception('load error'));

      await viewModel.loadBooks();

      expect(viewModel.state.error, contains('load error'));
      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.books, isEmpty);
    });

    test('loadBooks notifies listeners on success', () async {
      when(() => repository.getBooks()).thenAnswer((_) async => []);
      int notifyCount = 0;
      viewModel.addListener(() => notifyCount++);

      await viewModel.loadBooks();

      expect(notifyCount, greaterThanOrEqualTo(2));
    });

    test('loadBooks notifies listeners on error', () async {
      when(() => repository.getBooks()).thenThrow(Exception('load error'));
      int notifyCount = 0;
      viewModel.addListener(() => notifyCount++);

      await viewModel.loadBooks();

      expect(notifyCount, greaterThanOrEqualTo(2));
    });

    test('loadBooks with multiple books returns all of them', () async {
      when(() => repository.getBooks()).thenAnswer((_) async => [_bookA, _bookB, _bookC]);

      await viewModel.loadBooks();

      expect(viewModel.state.books, hasLength(3));
    });

    test('isLoading is false after loadBooks completes regardless of outcome', () async {
      when(() => repository.getBooks()).thenThrow(Exception());
      await viewModel.loadBooks();
      expect(viewModel.state.isLoading, isFalse);

      when(() => repository.getBooks()).thenAnswer((_) async => []);
      await viewModel.loadBooks();
      expect(viewModel.state.isLoading, isFalse);
    });

    test('getBooks is called once per loadBooks invocation', () async {
      when(() => repository.getBooks()).thenAnswer((_) async => []);

      await viewModel.loadBooks();

      verify(() => repository.getBooks()).called(1);
    });
  });
}
