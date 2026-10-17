import 'package:flutter/material.dart';

/// Design tokens from requirment/refrence.png.
class FluxColors {
  final Color bg;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color red;
  final Color green;

  const FluxColors._({
    required this.bg,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.red,
    required this.green,
  });

  static const dark = FluxColors._(
    bg: Color(0xFF000000),
    border: Color(0xFF2A2A2A),
    text: Color(0xFFE5E5E5),
    textSecondary: Color(0xFF8E8E8E),
    red: Color(0xFFD71921),
    green: Color(0xFF00FF66),
  );

  static const light = FluxColors._(
    bg: Color(0xFFF5F5F5),
    border: Color(0xFFD6D6D6),
    text: Color(0xFF111111),
    textSecondary: Color(0xFF6B6B6B),
    red: Color(0xFFD71921),
    green: Color(0xFF00B84A),
  );

  static FluxColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

const String kMono = 'monospace';

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? FluxColors.dark : FluxColors.light;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.red,
      brightness: brightness,
    ).copyWith(surface: c.bg, primary: c.red, onSurface: c.text),
    fontFamily: kMono,
    dividerColor: c.border,
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.red),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.text,
      contentTextStyle: TextStyle(fontFamily: kMono, color: c.bg, fontSize: 12),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Small uppercase mono label used everywhere in the design.
TextStyle label(BuildContext context, {Color? color, double size = 11}) =>
    TextStyle(
      fontFamily: kMono,
      fontSize: size,
      letterSpacing: 1.2,
      color: color ?? FluxColors.of(context).textSecondary,
    );
