import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/models/book.dart';
import '../../data/repositories/book_repository.dart';
import '../../epub/models/epub_manifest_item.dart';
import '../../epub/parser/epub_parser.dart';

class BooksNotifier extends ChangeNotifier {
  BooksNotifier(this._repository);
  final BookRepository _repository;

  List<Book> books = [];
  bool isLoading = false;
  String? error;

  Future<void> loadBooks() async {
    isLoading = true;
    notifyListeners();
    try {
      books = await _repository.getBooks();
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addEpub(String pickedPath) async {
    isLoading = true;
    notifyListeners();
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final uuid = _newUuid();

      final booksDir = Directory('${docsDir.path}/books');
      await booksDir.create(recursive: true);
      final stableFilePath = '${booksDir.path}/$uuid.epub';
      await File(pickedPath).copy(stableFilePath);

      final bytes = await File(stableFilePath).readAsBytes();
      final epubBook = await compute(EpubParser.parseBytes, bytes);

      String? coverImagePath;
      final coverItem = _findCoverItem(epubBook.manifest);
      if (coverItem != null) {
        final archiveFile = epubBook.fileMap[coverItem.href];
        if (archiveFile != null) {
          final coversDir = Directory('${docsDir.path}/covers');
          await coversDir.create(recursive: true);
          final ext = coverItem.mediaType.contains('png') ? 'png' : 'jpg';
          coverImagePath = '${coversDir.path}/$uuid.$ext';
          await File(coverImagePath).writeAsBytes(
            Uint8List.fromList(archiveFile.content as List<int>),
          );
        }
      }

      await _repository.addBook(
        filePath: stableFilePath,
        title: epubBook.metadata.title ?? 'Unknown Title',
        author: epubBook.metadata.creator,
        coverImagePath: coverImagePath,
      );

      books = await _repository.getBooks();
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProgress(int id, double progress) async {
    await _repository.updateProgress(id, progress);
    books = await _repository.getBooks();
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
