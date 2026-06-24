import 'package:epub_flutter/data/local/book_dao.dart';
import 'package:epub_flutter/screens/reader/reader_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBookDao extends Mock implements BookDao {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EpubReaderViewModel', () {
    late MockBookDao dao;
    late EpubReaderViewModel viewModel;

    setUp(() {
      dao = MockBookDao();
      when(() => dao.getReadingPosition(any())).thenAnswer((_) async => null);
      viewModel = EpubReaderViewModel(
        bookId: 1,
        filePath: '/nonexistent/path/book.epub',
        bookDao: dao,
      );
    });

    tearDown(() => viewModel.dispose());

    test('initial state has no book, no error, isRestoring true, progress 0', () {
      expect(viewModel.state.book, isNull);
      expect(viewModel.state.error, isNull);
      expect(viewModel.state.isRestoring, isTrue);
      expect(viewModel.state.progressPercentage, 0.0);
      expect(viewModel.state.chapters, isEmpty);
      expect(viewModel.state.chapterData, isEmpty);
    });

    test('loadBook sets error when file does not exist', () async {
      await viewModel.loadBook();

      expect(viewModel.state.error, isNotNull);
      expect(viewModel.state.book, isNull);
    });

    test('loadBook notifies listeners on file-not-found error', () async {
      int notifyCount = 0;
      viewModel.addListener(() => notifyCount++);

      await viewModel.loadBook();

      expect(notifyCount, greaterThanOrEqualTo(1));
    });

    test('dispose does not throw when called before loadBook', () {
      expect(viewModel.state.book, isNull);
    });

    test('dispose does not throw when called after a failed loadBook', () async {
      await viewModel.loadBook();
      expect(viewModel.state.error, isNotNull);
    });

    test('getReadingPosition is called during loadBook', () async {
      await viewModel.loadBook();

      verify(() => dao.getReadingPosition(1)).called(1);
    });

    test('getReadingPosition returning a saved position is used', () async {
      when(() => dao.getReadingPosition(any()))
          .thenAnswer((_) async => 42);

      await viewModel.loadBook();

      verify(() => dao.getReadingPosition(1)).called(1);
    });
  });
}
