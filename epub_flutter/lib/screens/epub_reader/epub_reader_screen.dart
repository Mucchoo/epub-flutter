import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../data/local/app_database.dart';
import '../../data/local/book_dao.dart';
import '../../epub/cfi/epub_cfi.dart';
import '../../epub/models/epub_book.dart';
import '../../epub/models/epub_spine_item.dart';
import '../../epub/parser/epub_parser.dart';
import '../../epub/progress/epub_progress.dart';
import '../../epub/progress/epub_progress_tracker.dart';
import '../../epub/styling/font_loader_service.dart';
import '../../theme/app_colors.dart';
import '../settings/reading_settings_notifier.dart';
import 'content_renderer.dart';
import 'epub_chapter_view.dart';
import 'epub_parser_isolate.dart';

class EpubReaderScreen extends StatefulWidget {
  final String filePath;
  final int bookId;

  const EpubReaderScreen({
    super.key,
    required this.filePath,
    required this.bookId,
  });

  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen> {
  EpubBook? _book;
  String? _error;
  List<EpubSpineItem> _chapters = [];

  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener =
      ItemPositionsListener.create();

  final _chapterNodeKeys = <int, List<NodeKey>>{};
  final _progressNotifier = ValueNotifier<double>(0.0);
  EpubProgressTracker? _tracker;
  String? _resumeCfi;
  ({int index, double alignment})? _resumeScroll;
  Map<String, List<int>> _cssFileBytes = {};
  Future<SendPort>? _isolateSendPort;
  Isolate? _parserIsolate;

  late final BookDao _bookDao = BookDao(AppDatabase.instance);

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  Future<void> _loadBook() async {
    try {
      _resumeCfi = await _bookDao.getCfi(widget.bookId);
      _resumeScroll = await _bookDao.getScrollPosition(widget.bookId);

      final bytes = await File(widget.filePath).readAsBytes();
      final book = await compute(EpubParser.parseBytes, bytes);
      if (!mounted) return;

      // Extract all CSS bytes once — passed to every chapter isolate.
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

      // Spawn the single long-lived parser isolate.
      final handle = await spawnChapterParserIsolate();

      final chapters = book.spine.where((s) => s.linear).toList();
      final chapterWeights = _computeChapterWeights(book.fileMap, chapters);

      final tracker = EpubProgressTracker(
        bookId: widget.bookId,
        chapters: chapters,
        positionsListener: _positionsListener,
        onSave: _onProgressSave,
        chapterWeights: chapterWeights,
      );

      _positionsListener.itemPositions.addListener(_onPositionsChanged);
      tracker.start();

      setState(() {
        _book = book;
        _chapters = chapters;
        _tracker = tracker;
        _cssFileBytes = cssFileBytes;
        _isolateSendPort = Future.value(handle.sendPort);
        _parserIsolate = handle.isolate;
      });

      if (_resumeScroll != null || _resumeCfi != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _onPositionsChanged() {
    _progressNotifier.value = _tracker?.currentPercentage ?? 0.0;
  }

  Future<void> _onProgressSave(EpubProgress progress) async {
    await _bookDao.saveCfi(progress.bookId, progress.cfi);
    await _bookDao.updateProgress(progress.bookId, progress.percentage);
    await _bookDao.saveScrollPosition(progress.bookId, progress.scrollIndex, progress.scrollAlignment);
  }

  void _restorePosition() {
    final scroll = _resumeScroll;
    if (scroll != null) {
      _scrollController.jumpTo(index: scroll.index, alignment: scroll.alignment);
      return;
    }
    // Fallback: CFI-based chapter-level restore for books with no scroll position saved yet.
    final cfiString = _resumeCfi;
    if (cfiString == null) return;
    final cfi = EpubCfi.parse(cfiString);
    if (cfi == null) return;
    final listIndex = (cfi.spineIndex ~/ 2) - 1;
    if (listIndex < 0 || listIndex >= _chapters.length) return;
    _scrollController.jumpTo(index: listIndex);
  }

  void _onChapterKeysReady(int spineIndex, List<NodeKey> keys) {
    _chapterNodeKeys[spineIndex] = keys;
    _tracker?.updateChapterKeys(spineIndex, keys);
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
    _progressNotifier.dispose();
    _parserIsolate?.kill(priority: Isolate.immediate);
    super.dispose();
  }

  AppBar _buildAppBar(String title) {
    return AppBar(
      backgroundColor: appBg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      foregroundColor: appTextDark,
      iconTheme: const IconThemeData(color: appTextDark),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: appTextDark,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: appBg,
        appBar: _buildAppBar('Error'),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    if (_book == null) {
      return Scaffold(
        backgroundColor: appBg,
        appBar: _buildAppBar('Opening…'),
        body: const Center(
          child: CircularProgressIndicator(color: appTextDark),
        ),
      );
    }

    return Scaffold(
      backgroundColor: appBg,
      appBar: AppBar(
        backgroundColor: appBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: appTextDark,
        iconTheme: const IconThemeData(color: appTextDark),
        title: Text(
          _book!.metadata.title ?? 'Book',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: appTextDark,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Stack(
        children: [
          ScrollablePositionedList.builder(
            itemCount: _chapters.length,
            itemScrollController: _scrollController,
            itemPositionsListener: _positionsListener,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            itemBuilder: (context, index) {
              final settings = ReadingSettingsScope.of(context);
              return EpubChapterView(
                book: _book!,
                spineIndex: _book!.spine.indexOf(_chapters[index]),
                onLinkTap: (href, fragment) {},
                onKeysReady: _onChapterKeysReady,
                cssFileBytes: _cssFileBytes,
                isolateSendPort: _isolateSendPort!,
                userFontSizeMultiplier: settings.fontSizeMultiplier,
              );
            },
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: ValueListenableBuilder<double>(
              valueListenable: _progressNotifier,
              builder: (_, pct, child) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(pct * 100).round()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
