import 'package:flutter/material.dart';

import '../books/books_screen.dart';
import '../settings/settings_screen.dart';

const _bg = Color(0xFFF2EDE3);
const _textDark = Color(0xFF1C0A00);
const _activePill = Color(0xFFF5C07A);

class LibraryShell extends StatefulWidget {
  const LibraryShell({super.key});

  @override
  State<LibraryShell> createState() => _LibraryShellState();
}

class _LibraryShellState extends State<LibraryShell> {
  int _selectedIndex = 0;

  static const _screens = [
    BooksScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selectedIndex, required this.onTap});
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        border: Border(
          top: BorderSide(color: _textDark.withValues(alpha: 0.15), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            spacing: 20,
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.menu_book_rounded,
                  label: 'Books',
                  selected: selectedIndex == 0,
                  onTap: () => onTap(0),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.settings,
                  label: 'Settings',
                  selected: selectedIndex == 1,
                  onTap: () => onTap(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _activePill : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: _textDark,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: _textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
