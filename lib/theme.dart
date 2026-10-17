import 'package:flutter/material.dart';

/// Design tokens from requirment/new_ref.png.
class FluxColors {
  final Color bg;
  final Color surface;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color red;
  final Color green;
  final bool isDark;

  const FluxColors._({
    required this.bg,
    required this.surface,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.red,
    required this.green,
    required this.isDark,
  });

  static const dark = FluxColors._(
    bg: Color(0xFF000000),
    surface: Color(0xFF0A0A0A),
    border: Color(0xFF2A2A2A),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF8E8E8E),
    red: Color(0xFFD71921),
    green: Color(0xFF00FF66),
    isDark: true,
  );

  static const light = FluxColors._(
    bg: Color(0xFFF5F5F5),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE5E5E5),
    text: Color(0xFF000000),
    textSecondary: Color(0xFF888888),
    red: Color(0xFFD71921),
    green: Color(0xFF00B84A),
    isDark: false,
  );

  static FluxColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Spacing scale from the design tokens: 4 / 8 / 12 / 16 / 24.
class Space {
  static const double xs = 4, s = 8, m = 12, l = 16, xl = 24;
}

/// Card radius from the design (28-32 px).
const double kCardRadius = 28;

const String kMono = 'GeistMono';
const String kSans = 'Inter';

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
    fontFamily: kSans,
    dividerColor: c.border,
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.red),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.text,
      contentTextStyle: TextStyle(fontFamily: kMono, color: c.bg, fontSize: 12),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(backgroundColor: c.surface),
  );
}

/// Small mono label (captions, timestamps, buttons).
TextStyle label(BuildContext context, {Color? color, double size = 11}) =>
    TextStyle(
      fontFamily: kMono,
      fontSize: size,
      letterSpacing: 1.0,
      color: color ?? FluxColors.of(context).textSecondary,
    );

/// Sans body text (titles, names).
TextStyle sans(BuildContext context,
        {Color? color, double size = 14, FontWeight? weight}) =>
    TextStyle(
      fontFamily: kSans,
      fontSize: size,
      fontWeight: weight,
      color: color ?? FluxColors.of(context).text,
    );
