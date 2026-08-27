import 'package:flutter/material.dart';

/// Application-wide theming.
///
/// A dark, cinema-style theme fits a streaming app. Colors are defined once
/// here and consumed via `Theme.of(context)` throughout the UI.
class AppTheme {
  const AppTheme._();

  static const Color _primary = Color(0xFF7C4DFF); // vivid violet
  static const Color _background = Color(0xFF0E0E12);
  static const Color _surface = Color(0xFF1A1A22);

  static ThemeData get dark {
    final colorScheme = const ColorScheme.dark(
      primary: _primary,
      secondary: Color(0xFF00E5FF),
      surface: _surface,
      onSurface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _background,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: _background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: CardTheme(
        color: _surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _surface,
        selectedColor: _primary,
        labelStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _surface,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    );
  }
}
