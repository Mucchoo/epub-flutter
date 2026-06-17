import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../data/local/app_database.dart';
import '../../data/local/book_dao.dart';
import '../../epub/models/epub_book.dart';
import '../../epub/models/epub_content_node.dart';
import '../../epub/models/epub_spine_item.dart';
import '../../epub/parser/epub_parser.dart';
import '../../epub/styling/computed_style.dart';
import '../../epub/styling/font_loader_service.dart';
import 'content_renderer.dart';
import 'epub_parser_isolate.dart';

typedef ChapterData = ({
  List<EpubContentNode> nodes,
  Map<int, ComputedStyle> styleMap,
});

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
  List<ChapterData?> _chapterData = [];
  Map<String, List<int>> _cssFileBytes = {};
  Isolate? _parserIsolate;

  ScrollController? _scrollController;
  Timer? _debounce;
  double _progressPercentage = 0.0;
  final Map<int, List<NodeKey>> _chapterNodeKeys = {};

  bool _isRestoring = true;
  bool get isRestoring => _isRestoring;
  bool _disposed = false;

  EpubBook? get book => _book;
  String? get error => _error;
  List<EpubSpineItem> get chapters => _chapters;
  List<ChapterData?> get chapterData => _chapterData;
  Map<String, List<int>> get cssFileBytes => _cssFileBytes;
  double get progressPercentage => _progressPercentage;
  ScrollController? get scrollController => _scrollController;

  Future<void> loadBook() async {
    try {
      final resumeOffset = await _bookDao.getScrollPosition(_bookId);
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
      final chapterData = List<ChapterData?>.filled(chapters.length, null);
      for (int i = 0; i < chapters.length; i++) {
        final spineItem = chapters[i];
        final href = spineItem.manifestItem.href;
        final file = book.fileMap[href];
        if (file == null) {
          chapterData[i] = (nodes: [], styleMap: {});
          continue;
        }

        final replyPort = ReceivePort();
        handle.sendPort.send(
          ChapterParseRequest(
            replyTo: replyPort.sendPort,
            htmlBytes: file.content as List<int>,
            chapterHref: href,
            cssFileBytes: cssFileBytes,
            knownFilePaths: book.fileMap.keys.toSet(),
          ),
        );
        final result = await replyPort.first as ChapterParseResult;
        replyPort.close();
        chapterData[i] = (nodes: result.nodes, styleMap: result.styleMap);
      }

      _book = book;
      _chapters = chapters;
      _chapterData = chapterData;
      _cssFileBytes = cssFileBytes;
      _parserIsolate = handle.isolate;

      _scrollController = ScrollController();
      _scrollController!.addListener(_onScroll);

      notifyListeners();

      if (resumeOffset != null && resumeOffset > 0) {
        _jumpToResumeOffset(resumeOffset);
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void _jumpToResumeOffset(double offset) {
    double? lastMaxExtent;

    void attempt() {
      if (_disposed) {
        return;
      }

      final ctrl = _scrollController;
      if (ctrl == null || !ctrl.hasClients) {
        SchedulerBinding.instance.addPostFrameCallback((_) => attempt());
        return;
      }

      final pos = ctrl.position;
      if (!pos.hasContentDimensions) {
        SchedulerBinding.instance.addPostFrameCallback((_) => attempt());
        return;
      }

      final currentMax = pos.maxScrollExtent;

      if (currentMax != lastMaxExtent) {
        lastMaxExtent = currentMax;
        SchedulerBinding.instance.addPostFrameCallback((_) => attempt());
        return;
      }

      final target = offset.clamp(0.0, currentMax);
      ctrl.jumpTo(target);
      _isRestoring = false;
      notifyListeners();
    }

    SchedulerBinding.instance.addPostFrameCallback((_) => attempt());
  }

  void onChapterKeysReady(int spineIndex, List<NodeKey> keys) {
    _chapterNodeKeys[spineIndex] = keys;
  }

  void _onScroll() {
    if (_isRestoring) return;
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
    _disposed = true;
    _debounce?.cancel();
    _scrollController?.removeListener(_onScroll);
    _scrollController?.dispose();
    _parserIsolate?.kill(priority: Isolate.immediate);
    super.dispose();
  }
}
