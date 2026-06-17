import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/local/app_database.dart';
import '../../data/local/book_dao.dart';
import '../../epub/models/epub_content_node.dart';
import '../../epub/parser/content_parser.dart';
import '../../epub/parser/epub_parser.dart';
import '../../epub/styling/computed_style.dart';
import '../../epub/styling/css_cascade.dart';
import '../../epub/styling/css_parser.dart';
import '../../epub/styling/font_loader_service.dart';
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
  final Map<String, Uint8List> imageCache = {};
  ScrollController? _scrollController;
  Timer? _debounce;
  ScrollController? get scrollController => _scrollController;

  List<GlobalKey> chapterKeys = [];
  List<int> _chapterCharOffsets = [];
  int _totalChars = 0;
  ({int chapter, int node, String snippet})? _savedPosition;

  Future<void> loadBook() async {
    try {
      _savedPosition = await _bookDao.getReadingPosition(_bookId);
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

      // Precompute cumulative char offsets for progress tracking
      _chapterCharOffsets = [];
      int cumulative = 0;
      for (final data in chapterData) {
        _chapterCharOffsets.add(cumulative);
        if (data != null) {
          for (final node in data.nodes) {
            cumulative += node.extractText().length;
          }
        }
      }
      _totalChars = cumulative;

      chapterKeys = List.generate(chapters.length, (_) => GlobalKey());

      _state = _state.copyWith(
        book: book,
        chapters: chapters,
        chapterData: chapterData,
      );

      _scrollController = ScrollController();
      _scrollController!.addListener(_onScroll);
      notifyListeners();

      WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
    }
  }

  void _restorePosition() {
    final pos = _savedPosition;
    if (pos == null) {
      _state = _state.copyWith(isRestoring: false);
      notifyListeners();
      return;
    }

    final chapterIndex = _resolveChapter(pos);
    if (chapterIndex == null) {
      _state = _state.copyWith(isRestoring: false);
      notifyListeners();
      return;
    }

    final ctx = chapterKeys[chapterIndex].currentContext;
    if (ctx == null) {
      _state = _state.copyWith(isRestoring: false);
      notifyListeners();
      return;
    }

    Scrollable.ensureVisible(
      ctx,
      alignment: 0.0,
      duration: Duration.zero,
    );

    _state = _state.copyWith(isRestoring: false);
    _updateProgress();
    notifyListeners();
  }

  int? _resolveChapter(({int chapter, int node, String snippet}) pos) {
    final prefix = pos.snippet.substring(0, min(20, pos.snippet.length));

    // Fast path: check the hinted chapter/node
    if (pos.chapter < _state.chapterData.length) {
      final hintData = _state.chapterData[pos.chapter];
      if (hintData != null && pos.node < hintData.nodes.length) {
        final text = hintData.nodes[pos.node].extractText();
        if (text.startsWith(prefix)) return pos.chapter;
      }
    }

    // Fallback: search all chapters
    for (int c = 0; c < _state.chapterData.length; c++) {
      final data = _state.chapterData[c];
      if (data == null) continue;
      for (final node in data.nodes) {
        if (node.extractText().startsWith(prefix)) return c;
      }
    }

    return null;
  }

  void _onScroll() {
    if (_state.isRestoring) return;
    _updateProgress();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _save);
  }

  void _updateProgress() {
    if (_totalChars == 0) return;
    final ctrl = _scrollController;
    if (ctrl == null || !ctrl.hasClients) return;

    final result = _findVisibleChapter();
    if (result == null) return;
    final (chapterIndex, box) = result;

    final chapterStart = _chapterCharOffsets[chapterIndex];
    final chapterEnd = chapterIndex + 1 < _chapterCharOffsets.length
        ? _chapterCharOffsets[chapterIndex + 1]
        : _totalChars;
    final chapterChars = chapterEnd - chapterStart;

    const viewportTop = kToolbarHeight;
    final chapterTop = box.localToGlobal(Offset.zero).dy;
    final scrolledPast = (viewportTop - chapterTop).clamp(0.0, box.size.height);
    final withinFraction =
        box.size.height > 0 ? scrolledPast / box.size.height : 0.0;

    final charsBeforeViewport =
        chapterStart + (withinFraction * chapterChars).round();
    final progress =
        (charsBeforeViewport / _totalChars).clamp(0.0, 1.0);

    if (progress == _state.progressPercentage) return;
    _state = _state.copyWith(progressPercentage: progress);
    notifyListeners();
  }

  (int, RenderBox)? _findVisibleChapter() {
    const viewportTop = kToolbarHeight;

    // Find chapter whose top <= viewportTop and bottom > viewportTop
    for (int i = 0; i < chapterKeys.length; i++) {
      final ctx = chapterKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      final bottom = top + box.size.height;
      if (top <= viewportTop && bottom > viewportTop) return (i, box);
    }

    // Fallback: last chapter whose top is above viewportTop
    for (int i = chapterKeys.length - 1; i >= 0; i--) {
      final ctx = chapterKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      if (box.localToGlobal(Offset.zero).dy <= viewportTop) return (i, box);
    }

    return null;
  }

  void _save() {
    final result = _findVisibleChapter();
    if (result == null) return;
    final (chapterIndex, _) = result;

    final data = _state.chapterData[chapterIndex];
    if (data == null || data.nodes.isEmpty) return;

    final nodeIndex = data.nodes.indexWhere(
      (n) => n.extractText().isNotEmpty,
    );
    if (nodeIndex == -1) return;

    final fullText = data.nodes[nodeIndex].extractText();
    final snippet = fullText.substring(0, min(80, fullText.length));

    _bookDao.saveReadingPosition(_bookId, chapterIndex, nodeIndex, snippet);
    _bookDao.updateProgress(_bookId, _state.progressPercentage);
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
