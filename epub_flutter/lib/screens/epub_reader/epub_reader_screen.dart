import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../epub/models/epub_book.dart';
import '../../epub/models/epub_spine_item.dart';
import '../../epub/parser/epub_parser.dart';
import 'epub_chapter_view.dart';
import 'epub_toc_drawer.dart';

class EpubReaderScreen extends StatefulWidget {
  final String filePath;

  const EpubReaderScreen({super.key, required this.filePath});

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

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  Future<void> _loadBook() async {
    try {
      final data = await rootBundle.load('assets/The Thinking Machine.epub');
      final bytes = data.buffer.asUint8List();
      final book = await compute(EpubParser.parseBytes, bytes);
      if (!mounted) return;
      setState(() {
        _book = book;
        _chapters = book.spine.where((s) => s.linear).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    if (_book == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Opening…')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _book!.metadata.title ?? 'Book',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'Table of Contents',
            onPressed: () => _openToc(context),
          ),
        ],
      ),
      body: ScrollablePositionedList.builder(
        itemCount: _chapters.length,
        itemScrollController: _scrollController,
        itemPositionsListener: _positionsListener,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        itemBuilder: (context, index) {
          return EpubChapterView(
            book: _book!,
            spineIndex: _book!.spine.indexOf(_chapters[index]),
            onLinkTap: (href, fragment) => _navigateTo(href, fragment),
          );
        },
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
