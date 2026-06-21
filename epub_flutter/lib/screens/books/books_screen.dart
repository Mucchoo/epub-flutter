import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/local/app_database.dart';
import '../../data/local/book_dao.dart';
import '../../data/models/book.dart';
import '../../data/repositories/book_repository_impl.dart';
import '../../theme/app_colors.dart';
import '../reader/reader_screen.dart';
import 'books_view_model.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  late final BooksViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = BooksViewModel(
      BookRepositoryImpl(BookDao(AppDatabase.instance)),
    );
    _viewModel.loadBooks();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            final state = _viewModel.state;
            if (state.isLoading && state.books.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: appTextDark),
              );
            }
            final items = [
              ...state.books.map((b) => _BookCard(book: b, onReturn: _viewModel.loadBooks)),
              _AddEpubCard(viewModel: _viewModel),
            ];
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                    child: const Text(
                      'Books',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: appTextDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 24,
                      childAspectRatio: 0.52,
                    ),
                    delegate: SliverChildListDelegate(items),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book, required this.onReturn});
  final Book book;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final finished = book.progress >= 1.0;
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EpubReaderScreen(
              filePath: book.filePath,
              bookId: book.id,
            ),
          ),
        );
        onReturn();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: book.coverImagePath != null
                  ? Image.file(
                      File(book.coverImagePath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) =>
                          _CoverPlaceholder(title: book.title),
                    )
                  : _CoverPlaceholder(title: book.title),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: appTextDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            book.author ?? '',
            style: const TextStyle(fontSize: 12, color: appTextDark),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: book.progress,
              backgroundColor: const Color(0xFFDDD8CC),
              valueColor: const AlwaysStoppedAnimation<Color>(appGold),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 6),
          if (finished)
            Row(
              children: const [
                Icon(Icons.check_circle, size: 14, color: appGold),
                SizedBox(width: 4),
                Text(
                  'Finished',
                  style: TextStyle(
                    fontSize: 12,
                    color: appGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else
            Text(
              '${(book.progress * 100).round()}% Completed',
              style: const TextStyle(fontSize: 12, color: appTextDark),
            ),
        ],
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: appCoverDark,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _AddEpubCard extends StatelessWidget {
  const _AddEpubCard({required this.viewModel});
  final BooksViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _pickFile(context),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomPaint(
                painter: _DashedBorderPainter(),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8E3D8),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 28,
                          color: appTextDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Add epub',
                        style: TextStyle(
                          fontSize: 14,
                          color: appTextDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
      withData: false,
    );
    if (result == null || result.files.single.path == null) return;
    if (!context.mounted) return;
    await viewModel.addEpub(result.files.single.path!);
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    const radius = Radius.circular(8);
    final paint = Paint()
      ..color = const Color(0xFFBBB5A8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
          radius,
        ),
      );

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        dashPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
