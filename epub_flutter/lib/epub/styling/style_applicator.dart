import 'package:flutter/material.dart';

import 'computed_style.dart';

class StyleApplicator {
  // ── Color ──────────────────────────────────────────────────────────────────

  static Color? parseColor(String? value) {
    if (value == null || value == 'transparent' || value == 'inherit') {
      return null;
    }

    const named = {
      'black': 0xFF000000,
      'white': 0xFFFFFFFF,
      'red': 0xFFFF0000,
      'green': 0xFF008000,
      'blue': 0xFF0000FF,
      'gray': 0xFF808080,
      'grey': 0xFF808080,
      'darkgray': 0xFFA9A9A9,
      'darkgrey': 0xFFA9A9A9,
      'lightgray': 0xFFD3D3D3,
      'lightgrey': 0xFFD3D3D3,
      'silver': 0xFFC0C0C0,
      'navy': 0xFF000080,
      'maroon': 0xFF800000,
      'purple': 0xFF800080,
      'orange': 0xFFFFA500,
      'yellow': 0xFFFFFF00,
      'cyan': 0xFF00FFFF,
      'aqua': 0xFF00FFFF,
      'magenta': 0xFFFF00FF,
      'fuchsia': 0xFFFF00FF,
      'lime': 0xFF00FF00,
      'teal': 0xFF008080,
      'olive': 0xFF808000,
      'transparent': 0x00000000,
    };
    final lower = value.toLowerCase().trim();
    if (named.containsKey(lower)) return Color(named[lower]!);

    if (value.startsWith('#')) {
      final hex = value.substring(1);
      if (hex.length == 3) {
        final r = int.parse(hex[0] * 2, radix: 16);
        final g = int.parse(hex[1] * 2, radix: 16);
        final b = int.parse(hex[2] * 2, radix: 16);
        return Color(0xFF000000 | (r << 16) | (g << 8) | b);
      }
      if (hex.length == 6) {
        return Color(0xFF000000 | int.parse(hex, radix: 16));
      }
      if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    }

    final rgbMatch = RegExp(
      r'rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([\d.]+))?\s*\)',
    ).firstMatch(value);
    if (rgbMatch != null) {
      final r = int.parse(rgbMatch.group(1)!);
      final g = int.parse(rgbMatch.group(2)!);
      final b = int.parse(rgbMatch.group(3)!);
      final a = rgbMatch.group(4) != null
          ? (double.parse(rgbMatch.group(4)!) * 255).round()
          : 255;
      return Color.fromARGB(a, r, g, b);
    }

    return null;
  }

  // ── Length ─────────────────────────────────────────────────────────────────

  static double? parseLength(
    String? value, {
    double parentFontSize = 16.0,
    double baseFontSize = 16.0,
  }) {
    if (value == null || value == 'auto' || value == 'none') return null;
    value = value.trim();

    if (value == '0') return 0;
    if (value.endsWith('px')) {
      return double.tryParse(value.substring(0, value.length - 2));
    }
    if (value.endsWith('em')) {
      final n = double.tryParse(value.substring(0, value.length - 2));
      return n != null ? n * parentFontSize : null;
    }
    if (value.endsWith('rem')) {
      final n = double.tryParse(value.substring(0, value.length - 3));
      return n != null ? n * baseFontSize : null;
    }
    if (value.endsWith('%')) {
      final n = double.tryParse(value.substring(0, value.length - 1));
      return n != null ? n / 100 * parentFontSize : null;
    }
    if (value.endsWith('pt')) {
      final n = double.tryParse(value.substring(0, value.length - 2));
      return n != null ? n * 1.333 : null;
    }
    if (value == 'smaller') return parentFontSize * 0.83;
    if (value == 'larger') return parentFontSize * 1.2;
    return double.tryParse(value);
  }

  // ── TextStyle ──────────────────────────────────────────────────────────────

  static TextStyle toTextStyle(
    ComputedStyle style, {
    double parentFontSize = 16.0,
    double baseFontSize = 16.0,
  }) {
    final fontSize = parseLength(
          style.getValue('font-size'),
          parentFontSize: parentFontSize,
          baseFontSize: baseFontSize,
        ) ??
        parentFontSize;

    return TextStyle(
      fontSize: fontSize,
      fontWeight: _parseFontWeight(style.getValue('font-weight')),
      fontStyle: _parseFontStyle(style.getValue('font-style')),
      color: parseColor(style.getValue('color')),
      decoration: _parseTextDecoration(style.getValue('text-decoration')),
      decorationColor:
          parseColor(style.getValue('text-decoration-color')),
      letterSpacing: parseLength(
        style.getValue('letter-spacing'),
        parentFontSize: fontSize,
      ),
      wordSpacing: parseLength(
        style.getValue('word-spacing'),
        parentFontSize: fontSize,
      ),
      height: _parseLineHeight(style.getValue('line-height'), fontSize),
      fontFamily: _parseFontFamily(style.getValue('font-family')),
    );
  }

  static FontWeight? _parseFontWeight(String? value) => switch (value) {
        'bold' || '700' => FontWeight.w700,
        'bolder' || '800' => FontWeight.w800,
        'lighter' || '300' => FontWeight.w300,
        '100' => FontWeight.w100,
        '200' => FontWeight.w200,
        '400' || 'normal' => FontWeight.w400,
        '500' => FontWeight.w500,
        '600' => FontWeight.w600,
        '900' => FontWeight.w900,
        _ => null,
      };

  static FontStyle? _parseFontStyle(String? value) => switch (value) {
        'italic' || 'oblique' => FontStyle.italic,
        'normal' => FontStyle.normal,
        _ => null,
      };

  static TextDecoration? _parseTextDecoration(String? value) {
    if (value == null || value == 'none') return TextDecoration.none;
    final decorations = <TextDecoration>[];
    if (value.contains('underline')) {
      decorations.add(TextDecoration.underline);
    }
    if (value.contains('overline')) {
      decorations.add(TextDecoration.overline);
    }
    if (value.contains('line-through')) {
      decorations.add(TextDecoration.lineThrough);
    }
    if (decorations.isEmpty) return null;
    return TextDecoration.combine(decorations);
  }

  static double? _parseLineHeight(String? value, double fontSize) {
    if (value == null || value == 'normal') return null;
    final bare = double.tryParse(value);
    if (bare != null) return bare;
    return parseLength(value, parentFontSize: fontSize);
  }

  static String? _parseFontFamily(String? value) {
    if (value == null) return null;
    const generics = {
      'serif',
      'sans-serif',
      'monospace',
      'cursive',
      'fantasy',
      'system-ui',
    };
    final families = value
        .split(',')
        .map((f) => f.trim().replaceAll(RegExp(r"""^['"]|['"]$"""), ''));
    return families.firstWhere(
      (f) => !generics.contains(f.toLowerCase()),
      orElse: () => families.first,
    );
  }

  // ── TextAlign ──────────────────────────────────────────────────────────────

  static TextAlign? parseTextAlign(String? value) => switch (value) {
        'left' => TextAlign.left,
        'right' => TextAlign.right,
        'center' => TextAlign.center,
        'justify' => TextAlign.justify,
        'start' => TextAlign.start,
        'end' => TextAlign.end,
        _ => null,
      };

  // ── TextTransform ──────────────────────────────────────────────────────────

  static String applyTextTransform(String text, String? value) =>
      switch (value) {
        'uppercase' => text.toUpperCase(),
        'lowercase' => text.toLowerCase(),
        'capitalize' => text
            .split(' ')
            .map((w) =>
                w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' '),
        _ => text,
      };

  // ── EdgeInsets (margin / padding) ──────────────────────────────────────────

  static EdgeInsets? parseEdgeInsets(ComputedStyle style, String prefix) {
    final top = style.getValue('$prefix-top');
    final right = style.getValue('$prefix-right');
    final bottom = style.getValue('$prefix-bottom');
    final left = style.getValue('$prefix-left');

    if (top != null || right != null || bottom != null || left != null) {
      final fontSize =
          parseLength(style.getValue('font-size')) ?? 16.0;
      return EdgeInsets.only(
        top: parseLength(top, parentFontSize: fontSize) ?? 0,
        right: parseLength(right, parentFontSize: fontSize) ?? 0,
        bottom: parseLength(bottom, parentFontSize: fontSize) ?? 0,
        left: parseLength(left, parentFontSize: fontSize) ?? 0,
      );
    }

    final shorthand = style.getValue(prefix);
    if (shorthand == null) return null;
    return _parseShorthandEdgeInsets(shorthand);
  }

  static EdgeInsets _parseShorthandEdgeInsets(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    final values = parts.map((p) => parseLength(p) ?? 0).toList();
    return switch (values.length) {
      1 => EdgeInsets.all(values[0]),
      2 => EdgeInsets.symmetric(
          vertical: values[0],
          horizontal: values[1],
        ),
      3 => EdgeInsets.only(
          top: values[0],
          right: values[1],
          bottom: values[2],
          left: values[1],
        ),
      _ => EdgeInsets.only(
          top: values[0],
          right: values[1],
          bottom: values[2],
          left: values[3],
        ),
    };
  }

  // ── BoxDecoration (background, border) ─────────────────────────────────────

  static BoxDecoration? toBoxDecoration(ComputedStyle style) {
    final bgColor = parseColor(style.getValue('background-color'));
    final border = _parseBorder(style);
    final borderRadius = _parseBorderRadius(style);

    if (bgColor == null && border == null && borderRadius == null) return null;

    return BoxDecoration(
      color: bgColor,
      border: border,
      borderRadius: borderRadius,
    );
  }

  static Border? _parseBorder(ComputedStyle style) {
    BorderSide? parseSide(String? value, Color fallbackColor) {
      if (value == null || value.contains('none') ||
          value.contains('hidden')) {
        return BorderSide.none;
      }
      final parts = value.trim().split(RegExp(r'\s+'));
      final widthStr = parts.firstWhere(
        (p) => p.endsWith('px') || p.endsWith('em'),
        orElse: () => '1px',
      );
      final width = parseLength(widthStr) ?? 1.0;
      final colorStr = parts.lastWhere(
        (p) =>
            !p.endsWith('px') &&
            !p.endsWith('em') &&
            p != 'solid' &&
            p != 'dashed' &&
            p != 'dotted' &&
            p != 'none' &&
            p != 'hidden',
        orElse: () => '',
      );
      final color = parseColor(colorStr) ?? fallbackColor;
      return BorderSide(color: color, width: width);
    }

    final elementColor =
        parseColor(style.getValue('color')) ?? Colors.black;

    final shorthand = style.getValue('border');
    if (shorthand != null) {
      final side = parseSide(shorthand, elementColor);
      if (side == null || side == BorderSide.none) return null;
      return Border.fromBorderSide(side);
    }

    final top = parseSide(style.getValue('border-top'), elementColor);
    final right = parseSide(style.getValue('border-right'), elementColor);
    final bottom = parseSide(style.getValue('border-bottom'), elementColor);
    final left = parseSide(style.getValue('border-left'), elementColor);

    if (top == null && right == null && bottom == null && left == null) {
      return null;
    }
    return Border(
      top: top ?? BorderSide.none,
      right: right ?? BorderSide.none,
      bottom: bottom ?? BorderSide.none,
      left: left ?? BorderSide.none,
    );
  }

  static BorderRadius? _parseBorderRadius(ComputedStyle style) {
    final value = style.getValue('border-radius');
    if (value == null) return null;
    final radius = parseLength(value) ?? 0;
    return BorderRadius.circular(radius);
  }
}
