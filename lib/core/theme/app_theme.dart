import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Font for app. Use 'Google Sans' if you add it under [flutter/fonts] in pubspec; else DM Sans from package.
const String _appFontFamily = 'Outfit';

const Color _defaultSeed = Color(0xFF6750A4);

TextStyle _withColor(TextStyle? s, Color color) {
  if (s == null) return TextStyle(fontSize: 14, color: color);
  return s.copyWith(color: color);
}

TextTheme _compactTextTheme(ColorScheme scheme) {
  final typography = Typography.material2021(
    colorScheme: scheme,
    platform: TargetPlatform.android,
  );
  final base = typography.black;
  final c = scheme.onSurface;
  final themed = TextTheme(
    displayLarge: _withColor(base.displayLarge, c),
    displayMedium: _withColor(base.displayMedium, c),
    displaySmall: _withColor(base.displaySmall, c),
    headlineLarge: _withColor(base.headlineLarge, c),
    headlineMedium: _withColor(base.headlineMedium, c),
    headlineSmall: _withColor(base.headlineSmall, c),
    titleLarge: _withColor(base.titleLarge, c),
    titleMedium: _withColor(base.titleMedium, c),
    titleSmall: _withColor(base.titleSmall, c),
    bodyLarge: _withColor(base.bodyLarge, c),
    bodyMedium: _withColor(base.bodyMedium, c),
    bodySmall: _withColor(base.bodySmall, c),
    labelLarge: _withColor(base.labelLarge, c),
    labelMedium: _withColor(base.labelMedium, c),
    labelSmall: _withColor(base.labelSmall, c),
  );
  try {
    return GoogleFonts.getTextTheme(_appFontFamily, themed);
  } catch (_) {
    return themed;
  }
}

ThemeData _buildTheme(Color seedColor, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    visualDensity: VisualDensity.compact,
    colorScheme: scheme,
    textTheme: _compactTextTheme(scheme),
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
}

ThemeData appTheme([Color? accentColor]) =>
    _buildTheme(accentColor ?? _defaultSeed, Brightness.light);

ThemeData appThemeDark([Color? accentColor]) =>
    _buildTheme(accentColor ?? _defaultSeed, Brightness.dark);
