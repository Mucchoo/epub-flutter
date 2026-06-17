import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../data/local/app_database.dart';
import '../../data/local/book_dao.dart';
import '../../epub/models/epub_content_node.dart';
import '../../epub/parser/content_parser.dart';
import '../../epub/parser/epub_parser.dart';
import '../../epub/styling/computed_style.dart';
import '../../epub/styling/css_cascade.dart';
import '../../epub/styling/css_parser.dart';
import '../../epub/styling/font_loader_service.dart';
import 'package:flutter/material.dart';
import 'reader_ui_state.dart';

class _ChapterParseRequest {
  const _ChapterParseRequest({
    required this.replyTo,
    required this.htmlBytes,
    required this.chapterHref,
    required this.cssFileBytes,
    required this.knownFilePaths,
  });

  final SendPort replyTo;
  final List<int> htmlBytes;
  final String chapterHref;
  final Map<String, List<int>> cssFileBytes;
  final Set<String> knownFilePaths;
}

typedef _ChapterParseResult = ({
  List<EpubContentNode> nodes,
  Map<int, ComputedStyle> styleMap,
});

void _isolateEntry(SendPort callerPort) {
  final receivePort = ReceivePort();
  callerPort.send(receivePort.sendPort);

  receivePort.listen((message) {
    if (message is! _ChapterParseRequest) return;

    final parser = ContentParser(
      chapterHref: message.chapterHref,
      knownFilePaths: message.knownFilePaths,
    );
    final nodes = parser.parse(message.htmlBytes);

    final allRules = <CssRule>[];
    for (final cssPath in parser.linkedStylesheetPaths) {
      final cssBytes = message.cssFileBytes[cssPath];
      if (cssBytes == null) continue;
      allRules.addAll(
        CssParser.parse(utf8.decode(cssBytes), sourceHref: cssPath),
      );
    }
    for (final cssText in parser.embeddedStyleTexts) {
      allRules.addAll(CssParser.parse(cssText));
    }

    final styleMap = CssCascade(allRules).resolveAll(nodes);
    message.replyTo.send((nodes: nodes.stripDom(), styleMap: styleMap));
  });
}

class EpubReaderViewModel extends ChangeNotifier {
  EpubReaderViewModel({
    required int bookId,
    required String filePath,
    BookDao? bookDao,
  }) : _bookId = bookId,
       _filePath = filePath,
       _bookDao = bookDao ?? BookDao(AppDatabase.instance);

  final int _bookId;
  final String _filePath;
  final BookDao _bookDao;

  ReaderUiState _state = const ReaderUiState();
  ReaderUiState get state => _state;

  Isolate? _parserIsolate;

  // Image cache — shared across all chapters, owned here so it survives rebuilds
  final Map<String, Uint8List> imageCache = {};

  // Scroll / progress state
  ScrollController? _scrollController;
  Timer? _debounce;
  bool _disposed = false;

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

      final receivePort = ReceivePort();
      final isolate = await Isolate.spawn(_isolateEntry, receivePort.sendPort);
      final sendPort = await receivePort.first as SendPort;
      receivePort.close();
      _parserIsolate = isolate;

      final chapters = book.spine.where((s) => s.linear).toList();
      final chapterData = List<ChapterData?>.filled(chapters.length, null);

      for (int i = 0; i < chapters.length; i++) {
        final href = chapters[i].manifestItem.href;
        final file = book.fileMap[href];
        if (file == null) {
          chapterData[i] = (nodes: [], styleMap: {});
          continue;
        }

        final replyPort = ReceivePort();
        sendPort.send(
          _ChapterParseRequest(
            replyTo: replyPort.sendPort,
            htmlBytes: file.content as List<int>,
            chapterHref: href,
            cssFileBytes: cssFileBytes,
            knownFilePaths: book.fileMap.keys.toSet(),
          ),
        );
        final result = await replyPort.first as _ChapterParseResult;
        replyPort.close();
        chapterData[i] = (nodes: result.nodes, styleMap: result.styleMap);
      }

      _state = _state.copyWith(
        book: book,
        chapters: chapters,
        chapterData: chapterData,
      );

      _scrollController = ScrollController();
      _scrollController!.addListener(_onScroll);

      notifyListeners();

      if (resumeOffset != null && resumeOffset > 0) {
        _jumpToResumeOffset(resumeOffset);
      }
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
    }
  }

  void _jumpToResumeOffset(double offset) {
    double? lastMaxExtent;

    void attempt() {
      if (_disposed) return;

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

      ctrl.jumpTo(offset.clamp(0.0, currentMax));
      _state = _state.copyWith(isRestoring: false);
      notifyListeners();
    }

    SchedulerBinding.instance.addPostFrameCallback((_) => attempt());
  }

  void _onScroll() {
    if (_state.isRestoring) return;
    _updateProgress();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _save);
  }

  void _updateProgress() {
    final ctrl = _scrollController;
    if (ctrl == null || !ctrl.hasClients) return;
    if (!ctrl.position.hasContentDimensions) return;

    final max = ctrl.position.maxScrollExtent;
    final updated = max > 0 ? (ctrl.offset / max).clamp(0.0, 1.0) : 0.0;
    if (updated == _state.progressPercentage) return;

    _state = _state.copyWith(progressPercentage: updated);
    notifyListeners();
  }

  void _save() {
    final ctrl = _scrollController;
    if (ctrl == null || !ctrl.hasClients) return;
    if (!ctrl.position.hasContentDimensions) return;

    _bookDao.updateProgress(_bookId, _state.progressPercentage);
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
