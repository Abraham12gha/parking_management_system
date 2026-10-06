import 'package:flutter/material.dart';

class AppTheme {
  static const _radius = BorderRadius.all(Radius.circular(12));
  static const _shape = RoundedRectangleBorder(
    borderRadius: _radius,
  );

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF5F8F5),

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
      backgroundColor: Color(0xFFF5F8F5),
      foregroundColor: Color(0xFF183B25),
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),

    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF000000)),
      bodyMedium: TextStyle(color: Color(0xFF000000)),
      titleLarge: TextStyle(color: Color(0xFF000000)),
    ),
    dividerColor: const Color(0xFFE2E9E3),
    cardColor: const Color(0xFFFFFFFF),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFFFFFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: const BorderSide(color: Color(0xFFDCE5DE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: const BorderSide(color: Color(0xFFDCE5DE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: const BorderSide(color: Color(0xFF2E7D4A), width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shape: _shape,
        minimumSize: const Size(44, 44),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: _shape,
        minimumSize: const Size(44, 44),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );

  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
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
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF1D2821),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shape: _shape,
        minimumSize: const Size(44, 44),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: _shape,
        minimumSize: const Size(44, 44),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
