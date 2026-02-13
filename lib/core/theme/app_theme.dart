import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Scale factor for compact UI (smaller than default).
const double _compactScale = 0.92;

/// Font for app. Use 'Google Sans' if you add it under [flutter/fonts] in pubspec; else DM Sans from package.
const String _appFontFamily = 'DM Sans';

TextStyle _scale(TextStyle? s, Color color) {
  if (s == null) return TextStyle(fontSize: 14 * _compactScale, color: color);
  return s.copyWith(
    color: color,
    fontSize: (s.fontSize ?? 14) * _compactScale,
  );
}

TextTheme _compactTextTheme(ColorScheme scheme) {
  final typography = Typography.material2021(colorScheme: scheme, platform: TargetPlatform.android);
  final base = typography.black;
  final c = scheme.onSurface;
  final scaled = TextTheme(
    displayLarge: _scale(base.displayLarge, c),
    displayMedium: _scale(base.displayMedium, c),
    displaySmall: _scale(base.displaySmall, c),
    headlineLarge: _scale(base.headlineLarge, c),
    headlineMedium: _scale(base.headlineMedium, c),
    headlineSmall: _scale(base.headlineSmall, c),
    titleLarge: _scale(base.titleLarge, c),
    titleMedium: _scale(base.titleMedium, c),
    titleSmall: _scale(base.titleSmall, c),
    bodyLarge: _scale(base.bodyLarge, c),
    bodyMedium: _scale(base.bodyMedium, c),
    bodySmall: _scale(base.bodySmall, c),
    labelLarge: _scale(base.labelLarge, c),
    labelMedium: _scale(base.labelMedium, c),
    labelSmall: _scale(base.labelSmall, c),
  );
  try {
    return GoogleFonts.getTextTheme(_appFontFamily, scaled);
  } catch (_) {
    return scaled;
  }
}

ThemeData get appTheme => ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.compact,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      textTheme: _compactTextTheme(
        ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        minLeadingWidth: 40,
        dense: true,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        toolbarHeight: 48,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        smallSizeConstraints: BoxConstraints(minWidth: 40, minHeight: 40),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      cardTheme: CardThemeData(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

ThemeData get appThemeDark => ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.compact,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      textTheme: _compactTextTheme(
        ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        minLeadingWidth: 40,
        dense: true,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        toolbarHeight: 48,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        smallSizeConstraints: BoxConstraints(minWidth: 40, minHeight: 40),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      cardTheme: CardThemeData(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
