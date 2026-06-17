import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/local/app_database.dart';
import '../../data/local/book_dao.dart';
import '../../epub/models/epub_book.dart';
import '../../epub/models/epub_spine_item.dart';
import '../../epub/parser/epub_parser.dart';
import '../../epub/styling/font_loader_service.dart';
import 'content_renderer.dart';
import 'epub_parser_isolate.dart';

class EpubReaderViewModel extends ChangeNotifier {
  EpubReaderViewModel({
    required this._bookId,
    required this._filePath,
    BookDao? bookDao,
  }) : _bookDao = bookDao ?? BookDao(AppDatabase.instance);

  final int _bookId;
  final String _filePath;
  final BookDao _bookDao;

  EpubBook? _book;
  String? _error;
  List<EpubSpineItem> _chapters = [];
  Map<String, List<int>> _cssFileBytes = {};
  Future<SendPort>? _isolateSendPort;
  Isolate? _parserIsolate;

  ScrollController? _scrollController;
  Timer? _debounce;
  double _progressPercentage = 0.0;
  final Map<int, List<NodeKey>> _chapterNodeKeys = {};

  EpubBook? get book => _book;
  String? get error => _error;
  List<EpubSpineItem> get chapters => _chapters;
  Map<String, List<int>> get cssFileBytes => _cssFileBytes;
  Future<SendPort>? get isolateSendPort => _isolateSendPort;
  double get progressPercentage => _progressPercentage;
  ScrollController? get scrollController => _scrollController;

  Future<void> loadBook() async {
    try {
      final resumeOffset = await _bookDao.getScrollPosition(_bookId);

      _scrollController = ScrollController(
        initialScrollOffset: resumeOffset ?? 0.0,
      );
      _scrollController!.addListener(_onScroll);

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

      _book = book;
      _chapters = chapters;
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
  }

  void _onScroll() {
    _updateProgress();

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _save);
  }

  void _updateProgress() {
    final ctrl = _scrollController;
    if (ctrl == null || !ctrl.hasClients) return;
    if (!ctrl.position.hasContentDimensions) return;

    final max = ctrl.position.maxScrollExtent;
    final newPercentage = max > 0 ? (ctrl.offset / max).clamp(0.0, 1.0) : 0.0;
    if (newPercentage == _progressPercentage) return;

    _progressPercentage = newPercentage;
    notifyListeners();
  }

  void _save() {
    final ctrl = _scrollController;
    if (ctrl == null || !ctrl.hasClients) return;
    if (!ctrl.position.hasContentDimensions) return;

    _bookDao.updateProgress(_bookId, _progressPercentage);
    _bookDao.saveScrollPosition(_bookId, ctrl.offset);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController?.removeListener(_onScroll);
    _scrollController?.dispose();
    _parserIsolate?.kill(priority: Isolate.immediate);
    super.dispose();
  }
}
