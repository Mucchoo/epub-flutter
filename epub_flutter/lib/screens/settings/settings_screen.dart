import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _fontSize = 0.35;
  int _selectedFont = 0;

  static const _fontStyles = ['Classical', 'Literary', 'Contemporary'];

  @override
  Widget build(BuildContext context) {
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
                      value: _fontSize,
                      onChanged: (v) => setState(() => _fontSize = v),
                    ),
                    const SizedBox(height: 24),
                    _FontStyleSection(
                      styles: _fontStyles,
                      selected: _selectedFont,
                      onSelect: (i) => setState(() => _selectedFont = i),
                    ),
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

class _FontStyleSection extends StatelessWidget {
  const _FontStyleSection({
    required this.styles,
    required this.selected,
    required this.onSelect,
  });
  final List<String> styles;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Font Style',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: appTextDark,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(styles.length, (i) {
          final isSelected = i == selected;
          return Padding(
            padding: EdgeInsets.only(bottom: i < styles.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isSelected ? appSelectedRow : const Color(0xFFF5F0E8),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      styles[i],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected ? appTextDark : appTextDark,
                      ),
                    ),
                    isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: appTextDark,
                            size: 22,
                          )
                        : Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFBBB5A8),
                                width: 1.5,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
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
