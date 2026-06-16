import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'reading_settings_notifier.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = ReadingSettingsScope.of(context);
    return Scaffold(
      backgroundColor: appBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: appTextDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                decoration: BoxDecoration(
                  color: appCardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FontSizeSection(
                      value: settings.fontSizeValue,
                      onChanged: settings.setFontSize,
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFCCC8BE), height: 1),
                    const SizedBox(height: 16),
                    _DemoText(multiplier: settings.fontSizeMultiplier),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _LogOutButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _FontSizeSection extends StatelessWidget {
  const _FontSizeSection({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Font Size',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: appTextDark,
              ),
            ),
            Text(
              'Adjust scale',
              style: TextStyle(fontSize: 13, color: Color(0xFF8A7A6A)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text(
              'A',
              style: TextStyle(fontSize: 13, color: appTextDark),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: appTextDark,
                  inactiveTrackColor: const Color(0xFFCCC8BE),
                  thumbColor: appTextDark,
                  overlayColor: appTextDark.withValues(alpha: 0.12),
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                ),
                child: Slider(
                  value: value,
                  onChanged: onChanged,
                ),
              ),
            ),
            const Text(
              'A',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: appTextDark,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DemoText extends StatelessWidget {
  const _DemoText({required this.multiplier});
  final double multiplier;

  @override
  Widget build(BuildContext context) {
    return Text(
      'This is how your text will look at this font size.',
      style: TextStyle(
        fontSize: 16.0 * multiplier,
        color: appTextDark,
        height: 1.5,
      ),
    );
  }
}

class _LogOutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.logout, color: Colors.white, size: 20),
        label: const Text(
          'Log Out',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: appTextDark,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
