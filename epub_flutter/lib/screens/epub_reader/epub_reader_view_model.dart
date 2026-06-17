import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../data/local/app_database.dart';
import '../../data/local/book_dao.dart';
import '../../epub/models/epub_book.dart';
import '../../epub/models/epub_spine_item.dart';
import '../../epub/parser/epub_parser.dart';
import '../../epub/progress/epub_progress.dart';
import '../../epub/progress/epub_progress_tracker.dart';
import '../../epub/styling/font_loader_service.dart';
import 'content_renderer.dart';
import 'epub_parser_isolate.dart';

class EpubReaderViewModel extends ChangeNotifier {
  EpubReaderViewModel({
    required int bookId,
    required String filePath,
    required ItemPositionsListener positionsListener,
    BookDao? bookDao,
  }) : _bookId = bookId,
       _filePath = filePath,
       _positionsListener = positionsListener,
       _bookDao = bookDao ?? BookDao(AppDatabase.instance);

  final int _bookId;
  final String _filePath;
  final ItemPositionsListener _positionsListener;
  final BookDao _bookDao;

  EpubBook? _book;
  String? _error;
  List<EpubSpineItem> _chapters = [];
  Map<String, List<int>> _cssFileBytes = {};
  Future<SendPort>? _isolateSendPort;
  Isolate? _parserIsolate;
  EpubProgressTracker? _tracker;
  String? _resumeCfi;
  ({int index, double alignment})? _resumeScroll;
  double _progressPercentage = 0.0;
  final _chapterNodeKeys = <int, List<NodeKey>>{};

  EpubBook? get book => _book;
  String? get error => _error;
  List<EpubSpineItem> get chapters => _chapters;
  Map<String, List<int>> get cssFileBytes => _cssFileBytes;
  Future<SendPort>? get isolateSendPort => _isolateSendPort;
  double get progressPercentage => _progressPercentage;
  String? get resumeCfi => _resumeCfi;
  ({int index, double alignment})? get resumeScroll => _resumeScroll;

  Future<void> loadBook() async {
    try {
      _resumeCfi = await _bookDao.getCfi(_bookId);
      _resumeScroll = await _bookDao.getScrollPosition(_bookId);

      final bytes = await File(_filePath).readAsBytes();
      final book = await compute(EpubParser.parseBytes, bytes);

      final cssFileBytes = <String, List<int>>{};
      final fontLoader = FontLoaderService(
        fileMap: book.fileMap,
        opfDir: book.opfDir,
      );
      for (final entry in book.fileMap.entries) {
        final key = entry.key.toLowerCase();
        if (key.endsWith('.css')) {
          final cssBytes = entry.value.content as List<int>;
          cssFileBytes[entry.key] = cssBytes;
          await fontLoader.loadFontsFromStylesheet(
            utf8.decode(cssBytes),
            entry.key,
          );
        }
      }

      final handle = await spawnChapterParserIsolate();
      final chapters = book.spine.where((s) => s.linear).toList();
      final chapterWeights = _computeChapterWeights(book.fileMap, chapters);

      final tracker = EpubProgressTracker(
        bookId: _bookId,
        chapters: chapters,
        positionsListener: _positionsListener,
        onSave: _onProgressSave,
        chapterWeights: chapterWeights,
      );

      _positionsListener.itemPositions.addListener(_onPositionsChanged);
      tracker.start();

      _book = book;
      _chapters = chapters;
      _tracker = tracker;
      _cssFileBytes = cssFileBytes;
      _isolateSendPort = Future.value(handle.sendPort);
      _parserIsolate = handle.isolate;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void onChapterKeysReady(int spineIndex, List<NodeKey> keys) {
    _chapterNodeKeys[spineIndex] = keys;
    _tracker?.updateChapterKeys(spineIndex, keys);
  }

  void _onPositionsChanged() {
    final newPercentage = _tracker?.currentPercentage ?? 0.0;
    // Only rebuild if the displayed value actually changed
    if (newPercentage == _progressPercentage) return;
    _progressPercentage = _tracker?.currentPercentage ?? 0.0;
    notifyListeners();
  }

  Future<void> _onProgressSave(EpubProgress progress) async {
    await _bookDao.saveCfi(progress.bookId, progress.cfi);
    print('updateProgress ${progress.percentage}');
    await _bookDao.updateProgress(progress.bookId, progress.percentage);
    await _bookDao.saveScrollPosition(
      progress.bookId,
      progress.scrollIndex,
      progress.scrollAlignment,
    );
  }

  static List<double> _computeChapterWeights(
    Map<String, dynamic> fileMap,
    List<EpubSpineItem> chapters,
  ) {
    final counts = chapters.map((ch) {
      final file = fileMap[ch.manifestItem.href];
      if (file == null) return 1;
      final text = utf8.decode(file.content as List<int>, allowMalformed: true);
      final charCount = text
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll(RegExp(r'\s+'), '')
          .length;
      return charCount < 1 ? 1 : charCount;
    }).toList();

    final total = counts.fold(0, (a, b) => a + b);
    return counts.map((c) => c / total).toList();
  }

  @override
  void dispose() {
    _positionsListener.itemPositions.removeListener(_onPositionsChanged);
    _tracker?.stop();
    _parserIsolate?.kill(priority: Isolate.immediate);
    super.dispose();
  }
}
