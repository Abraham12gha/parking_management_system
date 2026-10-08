import 'package:flutter/material.dart';

/// Shared visual language for the admin and operator workspaces.
/// Colors are intentionally restrained so operational data stays central.
class AppTheme {
  AppTheme._();

  static const _radius = BorderRadius.all(Radius.circular(10));
  static const _shape = RoundedRectangleBorder(borderRadius: _radius);

  static final lightTheme = _buildTheme(
    brightness: Brightness.light,
    background: const Color(0xFFF3F5F3),
    surface: const Color(0xFFFCFDFC),
    raisedSurface: const Color(0xFFF7F9F7),
    primary: const Color(0xFF356747),
    onPrimary: Colors.white,
    text: const Color(0xFF202923),
    mutedText: const Color(0xFF657168),
    border: const Color(0xFFDCE3DD),
    field: const Color(0xFFFFFFFF),
    success: const Color(0xFF2F704A),
    error: const Color(0xFFB3443E),
    warning: const Color(0xFF95651D),
    info: const Color(0xFF3D698B),
  );

  static final darkTheme = _buildTheme(
    brightness: Brightness.dark,
    background: const Color(0xFF171B19),
    surface: const Color(0xFF202623),
    raisedSurface: const Color(0xFF252C28),
    primary: const Color(0xFF83A88D),
    onPrimary: const Color(0xFF142219),
    text: const Color(0xFFE3E9E4),
    mutedText: const Color(0xFFADB8B0),
    border: const Color(0xFF39443D),
    field: const Color(0xFF252C28),
    success: const Color(0xFF8CB99A),
    error: const Color(0xFFE49A91),
    warning: const Color(0xFFD8B478),
    info: const Color(0xFF91B9D5),
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color raisedSurface,
    required Color primary,
    required Color onPrimary,
    required Color text,
    required Color mutedText,
    required Color border,
    required Color field,
    required Color success,
    required Color error,
    required Color warning,
    required Color info,
  }) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: dark ? const Color(0xFF9AA79D) : const Color(0xFF65766A),
      onSecondary: dark ? const Color(0xFF1D2520) : Colors.white,
      error: error,
      onError: dark ? const Color(0xFF321B18) : Colors.white,
      surface: surface,
      onSurface: text,
      surfaceContainerLowest: background,
      surfaceContainerLow: raisedSurface,
      surfaceContainer: surface,
      surfaceContainerHigh: dark
          ? const Color(0xFF2B332E)
          : const Color(0xFFEEF2EE),
      surfaceContainerHighest: dark
          ? const Color(0xFF333C36)
          : const Color(0xFFE6ECE7),
      onSurfaceVariant: mutedText,
      outline: border,
      outlineVariant: border.withValues(alpha: 0.72),
      shadow: Colors.black.withValues(alpha: dark ? 0.20 : 0.06),
      scrim: Colors.black.withValues(alpha: 0.45),
      inverseSurface: dark ? const Color(0xFFE3E9E4) : const Color(0xFF28312B),
      onInverseSurface: dark
          ? const Color(0xFF28312B)
          : const Color(0xFFF5F7F5),
      inversePrimary: dark ? const Color(0xFF356747) : const Color(0xFFA6C8AE),
      tertiary: success,
      onTertiary: dark ? const Color(0xFF142219) : Colors.white,
      surfaceTint: primary,
    );
    final baseText = Typography.material2021().black;
    final textTheme = baseText.copyWith(
      displayLarge: baseText.displayLarge?.copyWith(
        color: text,
        fontWeight: FontWeight.w600,
        height: 1.15,
      ),
      displayMedium: baseText.displayMedium?.copyWith(
        color: text,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      headlineLarge: baseText.headlineLarge?.copyWith(
        color: text,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      headlineMedium: baseText.headlineMedium?.copyWith(
        color: text,
        fontSize: 23,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
      headlineSmall: baseText.headlineSmall?.copyWith(
        color: text,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        color: text,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        color: text,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      titleSmall: baseText.titleSmall?.copyWith(
        color: text,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(
        color: text,
        fontSize: 14,
        height: 1.5,
      ),
      bodyMedium: baseText.bodyMedium?.copyWith(
        color: text,
        fontSize: 13,
        height: 1.45,
      ),
      bodySmall: baseText.bodySmall?.copyWith(
        color: mutedText,
        fontSize: 12,
        height: 1.4,
      ),
      labelLarge: baseText.labelLarge?.copyWith(
        color: text,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      labelMedium: baseText.labelMedium?.copyWith(
        color: mutedText,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
      labelSmall: baseText.labelSmall?.copyWith(
        color: mutedText,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      cardColor: surface,
      dividerColor: border,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        labelStyle: TextStyle(
          color: mutedText,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: mutedText.withValues(alpha: 0.78),
          fontSize: 13,
        ),
        helperStyle: TextStyle(color: mutedText, fontSize: 12, height: 1.4),
        errorStyle: TextStyle(color: error, fontSize: 12, height: 1.35),
        border: inputBorder(border),
        enabledBorder: inputBorder(border),
        focusedBorder: inputBorder(primary, 1.6),
        errorBorder: inputBorder(error),
        focusedErrorBorder: inputBorder(error, 1.6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(44, 42),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          shape: _shape,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 42),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          shape: _shape,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: _shape,
          side: BorderSide(color: border),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          shape: _shape,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          foregroundColor: mutedText,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: raisedSurface,
        selectedColor: primary.withValues(alpha: dark ? 0.22 : 0.10),
        disabledColor: raisedSurface.withValues(alpha: 0.55),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: TextStyle(
          color: text,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(
          color: primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border.withValues(alpha: 0.72)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(raisedSurface),
        headingTextStyle: TextStyle(
          color: mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        dataTextStyle: TextStyle(color: text, fontSize: 13),
        dividerThickness: 0.6,
        horizontalMargin: 18,
        columnSpacing: 24,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF333C36) : const Color(0xFF28312B),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark
            ? const Color(0xFF303934)
            : const Color(0xFF26312A),
        contentTextStyle: const TextStyle(
          color: Color(0xFFF4F7F4),
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        actionTextColor: dark
            ? const Color(0xFFA9D2B2)
            : const Color(0xFFB9DEC1),
        elevation: 6,
        insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: border,
      ),
    );
  }
}
