import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kFontSize = 'reading_font_size';

class ReadingSettingsNotifier extends ChangeNotifier {
  double _fontSizeValue = 0.35;

  double get fontSizeValue => _fontSizeValue;

  double get fontSizeMultiplier => 0.8 + _fontSizeValue * 0.7;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSizeValue = prefs.getDouble(_kFontSize) ?? 0.35;
  }

  void setFontSize(double value) {
    _fontSizeValue = value;
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontSize, _fontSizeValue);
  }
}

class ReadingSettingsScope extends InheritedNotifier<ReadingSettingsNotifier> {
  const ReadingSettingsScope({
    super.key,
    required ReadingSettingsNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ReadingSettingsNotifier of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ReadingSettingsScope>()!
        .notifier!;
  }
}
