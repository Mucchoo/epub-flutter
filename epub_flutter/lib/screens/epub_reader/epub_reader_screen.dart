import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../settings/reading_settings_notifier.dart';
import 'epub_chapter_view.dart';
import 'epub_reader_view_model.dart';

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
  late final EpubReaderViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = EpubReaderViewModel(
      bookId: widget.bookId,
      filePath: widget.filePath,
    );
    _viewModel.loadBook();
  }

  @override
  void dispose() {
    _viewModel.dispose();
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
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        if (_viewModel.error != null) {
          return Scaffold(
            backgroundColor: appBg,
            appBar: _buildAppBar('Error'),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _viewModel.error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (_viewModel.book == null) {
          return Scaffold(
            backgroundColor: appBg,
            appBar: _buildAppBar('Opening…'),
            body: const Center(
              child: CircularProgressIndicator(color: appTextDark),
            ),
          );
        }

        final book = _viewModel.book!;
        final settings = ReadingSettingsScope.of(context);

        return Scaffold(
          backgroundColor: appBg,
          appBar: AppBar(
            backgroundColor: appBg,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            foregroundColor: appTextDark,
            iconTheme: const IconThemeData(color: appTextDark),
            title: Text(
              book.metadata.title ?? 'Book',
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
              ListView.builder(
                controller: _viewModel.scrollController,
                itemCount: _viewModel.chapters.length,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                itemBuilder: (context, index) {
                  return EpubChapterView(
                    book: book,
                    spineIndex: book.spine.indexOf(_viewModel.chapters[index]),
                    onLinkTap: (href, fragment) {},
                    onKeysReady: _viewModel.onChapterKeysReady,
                    cssFileBytes: _viewModel.cssFileBytes,
                    isolateSendPort: _viewModel.isolateSendPort!,
                    userFontSizeMultiplier: settings.fontSizeMultiplier,
                  );
                },
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(_viewModel.progressPercentage * 100).round()}%',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
