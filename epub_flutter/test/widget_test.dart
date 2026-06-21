import 'package:epub_flutter/data/repositories/book_repository.dart';
import 'package:epub_flutter/screens/books/books_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBookRepository extends Mock implements BookRepository {}

void main() {
  testWidgets('BooksScreen renders empty library with Add epub button', (tester) async {
    final repo = MockBookRepository();
    when(() => repo.getBooks()).thenAnswer((_) async => []);

    await tester.pumpWidget(
      MaterialApp(home: BooksScreen(repository: repo)),
    );
    await tester.pump();

    expect(find.text('Books'), findsOneWidget);
    expect(find.text('Add epub'), findsOneWidget);
  });
}
