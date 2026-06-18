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
  ({int chapter, String snippet})? _savedPosition;

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
    print('[restore] _restorePosition called. savedPosition=$_savedPosition');
    if (_savedPosition == null) {
      print('[restore] No saved position — finishing immediately.');
      _state = _state.copyWith(isRestoring: false);
      _updateProgress();
      notifyListeners();
      return;
    }
    _restorePhase(1);
  }

  void _restorePhase(int phase) {
    final saved = _savedPosition!;
    final ctrl = _scrollController!;

    if (phase == 1) {
      print('[restore:p1] currentOffset=${ctrl.offset} maxScrollExtent=${ctrl.position.maxScrollExtent} chapterKeysCount=${chapterKeys.length} targetChapter=${saved.chapter}');
      final ctx = chapterKeys[saved.chapter].currentContext;
      if (ctx == null) {
        // ListView.builder only renders visible items — chapter may be off-screen.
        // Scroll forward by a viewport-height chunk to bring it into view.
        final viewportHeight = ctrl.position.viewportDimension;
        final nudge = (ctrl.offset + viewportHeight).clamp(0.0, ctrl.position.maxScrollExtent);
        print('[restore:p1] context for chapter ${saved.chapter} not ready. Nudging to offset=$nudge (viewport=$viewportHeight)');
        ctrl.jumpTo(nudge);
        WidgetsBinding.instance.addPostFrameCallback((_) => _restorePhase(1));
        return;
      }
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) {
        print('[restore:p1] RenderBox for chapter ${saved.chapter} not attached, retrying...');
        WidgetsBinding.instance.addPostFrameCallback((_) => _restorePhase(1));
        return;
      }
      final chapterTop = box.localToGlobal(Offset.zero).dy;
      final delta = chapterTop - kToolbarHeight;
      print('[restore:p1] chapterTop=$chapterTop kToolbarHeight=$kToolbarHeight delta=$delta currentOffset=${ctrl.offset}');
      if (delta.abs() < 1.0) {
        print('[restore:p1] Chapter ${saved.chapter} aligned. Advancing to phase 2.');
        WidgetsBinding.instance.addPostFrameCallback((_) => _restorePhase(2));
        return;
      }
      final newOffset = (ctrl.offset + delta).clamp(0.0, ctrl.position.maxScrollExtent);
      print('[restore:p1] Jumping to offset=$newOffset (was ${ctrl.offset})');
      ctrl.jumpTo(newOffset);
      WidgetsBinding.instance.addPostFrameCallback((_) => _restorePhase(1));
      return;
    }

    if (phase == 2) {
      final chapterIndex = saved.chapter;
      final data = _state.chapterData[chapterIndex];
      if (data == null || data.nodes.isEmpty) {
        print('[restore:p2] No data for chapter $chapterIndex — finishing.');
        _finishRestore();
        return;
      }

      final ctx = chapterKeys[chapterIndex].currentContext;
      if (ctx == null) {
        print('[restore:p2] context not ready, retrying...');
        WidgetsBinding.instance.addPostFrameCallback((_) => _restorePhase(2));
        return;
      }
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) {
        print('[restore:p2] RenderBox not attached, retrying...');
        WidgetsBinding.instance.addPostFrameCallback((_) => _restorePhase(2));
        return;
      }

      final snippetNode = data.nodes.indexWhere(
        (n) => n.extractText().contains(saved.snippet),
      );
      print('[restore:p2] snippet="${saved.snippet}" snippetNode=$snippetNode totalNodes=${data.nodes.length}');
      if (snippetNode == -1) {
        print('[restore:p2] Snippet not found in chapter $chapterIndex — finishing.');
        _finishRestore();
        return;
      }

      final chapterChars = data.nodes.fold(
        0,
        (sum, n) => sum + n.extractText().length,
      );
      int cumBefore = 0;
      for (int i = 0; i < snippetNode; i++) {
        cumBefore += data.nodes[i].extractText().length;
      }

      // Use intra-node char position for accurate fraction within the chapter.
      final nodeText = data.nodes[snippetNode].extractText();
      final snippetStart = nodeText.indexOf(saved.snippet);
      final charOffset = cumBefore + (snippetStart == -1 ? 0 : snippetStart);
      final targetFraction = chapterChars > 0 ? charOffset / chapterChars : 0.0;
      final targetPixelIntoChapter = targetFraction * box.size.height;

      final chapterTop = box.localToGlobal(Offset.zero).dy;
      final scrolledPast = (kToolbarHeight - chapterTop).clamp(0.0, box.size.height);

      print('[restore:p2] chapterHeight=${box.size.height} chapterChars=$chapterChars cumBefore=$cumBefore snippetStart=$snippetStart charOffset=$charOffset targetFraction=$targetFraction targetPixelIntoChapter=$targetPixelIntoChapter scrolledPast=$scrolledPast currentOffset=${ctrl.offset}');

      if (scrolledPast >= targetPixelIntoChapter - 1.0) {
        print('[restore:p2] Reached target (scrolledPast=$scrolledPast >= targetPixelIntoChapter=$targetPixelIntoChapter) — finishing.');
        _finishRestore();
        return;
      }

      final nudge = min(20.0, targetPixelIntoChapter - scrolledPast);
      final newOffset = (ctrl.offset + nudge).clamp(0.0, ctrl.position.maxScrollExtent);
      print('[restore:p2] Nudging by $nudge to offset=$newOffset');
      ctrl.jumpTo(newOffset);
      WidgetsBinding.instance.addPostFrameCallback((_) => _restorePhase(2));
    }
  }

  void _finishRestore() {
    print('[restore] _finishRestore called. Final offset=${_scrollController?.offset}');
    _state = _state.copyWith(isRestoring: false);
    _updateProgress();
    notifyListeners();
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
    if (result == null) {
      print('[save] _findVisibleChapter returned null — skipping save.');
      return;
    }
    final (chapterIndex, box) = result;

    final data = _state.chapterData[chapterIndex];
    if (data == null || data.nodes.isEmpty) {
      print('[save] No data for chapter $chapterIndex — skipping save.');
      return;
    }

    const viewportTop = kToolbarHeight;
    final chapterTop = box.localToGlobal(Offset.zero).dy;
    final scrolledPast = (viewportTop - chapterTop).clamp(0.0, box.size.height);
    final chapterFraction = box.size.height > 0 ? scrolledPast / box.size.height : 0.0;

    final chapterChars = data.nodes.fold(0, (s, n) => s + n.extractText().length);
    int cumulative = 0;
    int targetNode = 0;
    for (int i = 0; i < data.nodes.length; i++) {
      final nodeChars = data.nodes[i].extractText().length;
      if (chapterChars > 0 && (cumulative + nodeChars) / chapterChars >= chapterFraction) {
        targetNode = i;
        break;
      }
      cumulative += nodeChars;
      targetNode = i;
    }

    final fullText = data.nodes[targetNode].extractText();
    if (fullText.isEmpty) {
      print('[save] Target node $targetNode in chapter $chapterIndex has empty text — skipping save.');
      return;
    }
    final snippet = fullText.substring(0, min(80, fullText.length));

    print('[save] chapter=$chapterIndex chapterFraction=$chapterFraction targetNode=$targetNode snippet="$snippet"');
    _bookDao.saveReadingPosition(_bookId, chapterIndex, snippet);
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
