import 'package:flutter/material.dart';

class AppTheme {
  // Light Theme
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFFFFFFF),

    colorScheme: const ColorScheme.light(
      primary: Color(0xFF1B5E20),
      secondary: Color(0xFF2E7D32),
      tertiary: Color(0xFF66BB6A),
      surface: Color(0xFFFFFFFF),
      onPrimary: Color(0xFFFFFFFF),
      onSecondary: Color(0xFFFFFFFF),
      onSurface: Color(0xFF000000),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1B5E20),
      foregroundColor: Color(0xFFFFFFFF),
    ),

    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF000000)),
      bodyMedium: TextStyle(color: Color(0xFF000000)),
      titleLarge: TextStyle(color: Color(0xFF000000)),
    ),
  );

  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF101713),

    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF81A989),
      secondary: Color(0xFF6F9277),
      tertiary: Color(0xFFA0B8A3),
      surface: Color(0xFF19211C),
      onPrimary: Color(0xFF102016),
      onSecondary: Color(0xFFFFFFFF),
      onSurface: Color(0xFFE0E7E0),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF19211C),
      foregroundColor: Color(0xFFE0E7E0),
    ),

    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFFE0E7E0)),
      bodyMedium: TextStyle(color: Color(0xFFE0E7E0)),
      titleLarge: TextStyle(color: Color(0xFFE0E7E0)),
    ),
    dividerColor: const Color(0xFF344239),
    cardColor: const Color(0xFF19211C),
    inputDecorationTheme: const InputDecorationTheme(filled: true, fillColor: Color(0xFF1D2821)),
  );
}
