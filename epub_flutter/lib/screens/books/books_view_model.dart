import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/repositories/book_repository.dart';
import '../../epub/models/epub_manifest_item.dart';
import '../../epub/parser/epub_parser.dart';
import 'books_ui_state.dart';

class BooksViewModel extends ChangeNotifier {
  BooksViewModel(this._repository);

  final BookRepository _repository;

  BooksUiState _state = const BooksUiState();
  BooksUiState get state => _state;

  Future<void> loadBooks() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();
    try {
      final books = await _repository.getBooks();
      _state = _state.copyWith(books: books, isLoading: false);
    } catch (e) {
      _state = _state.copyWith(error: e.toString(), isLoading: false);
    }
    notifyListeners();
  }

  Future<void> addEpub(String pickedPath) async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final uuid = _newUuid();

      final booksDir = Directory('${docsDir.path}/books');
      await booksDir.create(recursive: true);
      final relativeFilePath = 'books/$uuid.epub';
      final stableFilePath = '${docsDir.path}/$relativeFilePath';
      await File(pickedPath).copy(stableFilePath);

      final bytes = await File(stableFilePath).readAsBytes();
      final epubBook = await compute(EpubParser.parseBytes, bytes);

      String? relativeCoverPath;
      final coverItem = _findCoverItem(epubBook.manifest);
      if (coverItem != null) {
        final archiveFile = epubBook.fileMap[coverItem.href];
        if (archiveFile != null) {
          final coversDir = Directory('${docsDir.path}/covers');
          await coversDir.create(recursive: true);
          final ext = coverItem.mediaType.contains('png') ? 'png' : 'jpg';
          relativeCoverPath = 'covers/$uuid.$ext';
          await File('${docsDir.path}/$relativeCoverPath').writeAsBytes(
            Uint8List.fromList(archiveFile.content as List<int>),
          );
        }
      }

      await _repository.addBook(
        filePath: relativeFilePath,
        title: epubBook.metadata.title ?? 'Unknown Title',
        author: epubBook.metadata.creator,
        coverImagePath: relativeCoverPath,
      );

      final books = await _repository.getBooks();
      _state = _state.copyWith(books: books, isLoading: false);
    } catch (e) {
      _state = _state.copyWith(error: e.toString(), isLoading: false);
    }
    notifyListeners();
  }

  static EpubManifestItem? _findCoverItem(
    Map<String, EpubManifestItem> manifest,
  ) {
    final byProperties = manifest.values
        .where((item) => item.properties.contains('cover-image'))
        .firstOrNull;
    if (byProperties != null) return byProperties;

    return manifest.values
        .where(
          (item) =>
              item.mediaType.startsWith('image/') &&
              (item.id.toLowerCase().contains('cover') ||
                  item.href.toLowerCase().contains('cover')),
        )
        .firstOrNull;
  }

  static String _newUuid() {
    final rand = Random.secure();
    return List.generate(
      16,
      (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
