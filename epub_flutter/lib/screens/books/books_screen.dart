import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../epub_reader/epub_reader_screen.dart';

const _bg = Color(0xFFF2EDE3);
const _textDark = Color(0xFF1C0A00);
const _gold = Color(0xFFC8A050);
const _coverDark = Color(0xFF150800);

class _Book {
  const _Book({
    required this.title,
    required this.author,
    required this.progress,
    required this.finished,
    required this.coverColor,
    required this.filePath,
  });
  final String title;
  final String author;
  final double progress;
  final bool finished;
  final Color coverColor;
  final String filePath;
}

const _books = [
  _Book(
    title: 'Meditations',
    author: 'Marcus Aurelius',
    progress: 0.65,
    finished: false,
    coverColor: _coverDark,
    filePath: '',
  ),
  _Book(
    title: 'The Great Gatsby',
    author: 'F. Scott Fitzgerald',
    progress: 0.12,
    finished: false,
    coverColor: Color(0xFF0A0A08),
    filePath: '',
  ),
  _Book(
    title: 'Pride & Prejudice',
    author: 'Jane Austen',
    progress: 1.0,
    finished: true,
    coverColor: Color(0xFF1A0C04),
    filePath: '',
  ),
];

class BooksScreen extends StatelessWidget {
  const BooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Text(
                'Books',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: _textDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 24,
                  childAspectRatio: 0.52,
                  children: [
                    ..._books.map((b) => _BookCard(book: b)),
                    const _AddEpubCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book});
  final _Book book;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EpubReaderScreen(filePath: book.filePath),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(color: book.coverColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            book.author,
            style: const TextStyle(fontSize: 12, color: _textDark),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: book.progress,
              backgroundColor: const Color(0xFFDDD8CC),
              valueColor: const AlwaysStoppedAnimation<Color>(_gold),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 6),
          if (book.finished)
            Row(
              children: const [
                Icon(Icons.check_circle, size: 14, color: _gold),
                SizedBox(width: 4),
                Text(
                  'Finished',
                  style: TextStyle(
                    fontSize: 12,
                    color: _gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else
            Text(
              '${(book.progress * 100).round()}% Completed',
              style: const TextStyle(fontSize: 12, color: _textDark),
            ),
        ],
      ),
    );
  }
}

class _AddEpubCard extends StatelessWidget {
  const _AddEpubCard();

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
                border: Border.all(
                  color: const Color(0xFFBBB5A8),
                  width: 1.5,
                  style: BorderStyle.none,
                ),
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
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Add epub',
                        style: TextStyle(
                          fontSize: 14,
                          color: _textDark,
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
    // TODO: add the picked epub file into the books grid
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
