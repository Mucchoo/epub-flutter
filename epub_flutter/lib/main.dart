import 'package:flutter/material.dart';

import 'screens/home/home_screen.dart';
import 'screens/settings/reading_settings_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = ReadingSettingsNotifier();
  await settings.load();
  runApp(ReadingSettingsScope(notifier: settings, child: const EpubReaderApp()));
}

class EpubReaderApp extends StatelessWidget {
  const EpubReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EPUB Reader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const LibraryShell(),
    );
  }
}
