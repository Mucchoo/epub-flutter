import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../data/local/app_database.dart';
import '../../data/local/book_dao.dart';
import '../../epub/cfi/epub_cfi.dart';
import '../../epub/cfi/epub_cfi_resolver.dart';
import '../../epub/models/epub_book.dart';
import '../../epub/models/epub_spine_item.dart';
import '../../epub/parser/epub_parser.dart';
import '../../epub/progress/epub_progress.dart';
import '../../epub/progress/epub_progress_tracker.dart';
import '../../theme/app_colors.dart';
import '../settings/reading_settings_notifier.dart';
import 'content_renderer.dart';
import 'epub_chapter_view.dart';
import 'epub_toc_drawer.dart';

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

  late final BookDao _bookDao = BookDao(AppDatabase.instance);

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  Future<void> _loadBook() async {
    try {
      _resumeCfi = await _bookDao.getCfi(widget.bookId);

      final bytes = await File(widget.filePath).readAsBytes();
      final book = await compute(EpubParser.parseBytes, bytes);
      if (!mounted) return;

      final chapters = book.spine.where((s) => s.linear).toList();

      final tracker = EpubProgressTracker(
        bookId: widget.bookId,
        chapters: chapters,
        positionsListener: _positionsListener,
        onSave: _onProgressSave,
      );

      _positionsListener.itemPositions.addListener(_onPositionsChanged);
      tracker.start();

      setState(() {
        _book = book;
        _chapters = chapters;
        _tracker = tracker;
      });

      if (_resumeCfi != null) {
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
  }

  void _restorePosition() {
    final cfiString = _resumeCfi;
    if (cfiString == null) return;
    final cfi = EpubCfi.parse(cfiString);
    if (cfi == null) return;

    final resolved = EpubCfiResolver.resolve(
      cfi: cfi,
      chapters: _chapters,
      chapterNodeKeys: _chapterNodeKeys,
    );
    if (resolved == null) return;

    _scrollController.jumpTo(index: resolved.spineIndex);

    if (resolved.nodeKey != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = resolved.nodeKey!.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.0);
      });
    }
  }

  void _onChapterKeysReady(int spineIndex, List<NodeKey> keys) {
    _chapterNodeKeys[spineIndex] = keys;
    _tracker?.updateChapterKeys(spineIndex, keys);
  }

  @override
  void dispose() {
    _positionsListener.itemPositions.removeListener(_onPositionsChanged);
    _tracker?.stop();
    _progressNotifier.dispose();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'Table of Contents',
            onPressed: () => _openToc(context),
          ),
        ],
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
                onLinkTap: (href, fragment) => _navigateTo(href, fragment),
                onKeysReady: _onChapterKeysReady,
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

  void _openToc(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EpubTocDrawer(
        tocItems: _book!.toc,
        onTap: (href, fragment) {
          Navigator.of(context).pop();
          _navigateTo(href, fragment);
        },
      ),
    );
  }

  void _navigateTo(String href, String? fragment) {
    final chapterIndex = _chapters.indexWhere(
      (s) => s.manifestItem.href == href,
    );
    if (chapterIndex == -1) return;
    _scrollController.scrollTo(
      index: chapterIndex,
      duration: const Duration(milliseconds: 300),
    );
  }
}
