import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium light palette (whitemodeprompt.md)
class AppPalette {
  AppPalette._();

  static const Color primaryRed = Color(0xFFD32F2F);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF1A1A1A);
  static const Color subtitle = Color(0xFF6B6B6B);
  static const Color beige = Color(0xFFF7EFE5);
  static const Color beigeAlt = Color(0xFFF5F5DC);
  static const Color outline = Color(0xFFE0E0E0);
  static const Color outlineSoft = Color(0xFFECECEC);
  static const Color navUnselected = Color(0xFF9E9E9E);
  static const Color emptyIcon = Color(0xFFBDBDBD);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
}

class AppTheme {
  /// Single canonical light theme for the entire app.
  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppPalette.primaryRed,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.montserratTextTheme(
        ThemeData(brightness: Brightness.light).textTheme,
      ),
      fontFamily: GoogleFonts.montserrat().fontFamily,
    );

    final scheme = base.colorScheme.copyWith(
      primary: AppPalette.primaryRed,
      onPrimary: AppPalette.onPrimary,
      secondary: AppPalette.beigeAlt,
      onSecondary: AppPalette.onSurface,
      surface: AppPalette.surface,
      onSurface: AppPalette.onSurface,
      error: AppPalette.primaryRed,
      onError: AppPalette.onPrimary,
      outline: AppPalette.outline,
      outlineVariant: AppPalette.outlineSoft,
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFFAF8F5),
      surfaceContainer: AppPalette.beige,
      surfaceContainerHigh: const Color(0xFFF2EDE6),
      surfaceContainerHighest: const Color(0xFFE8E3DB),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppPalette.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: AppPalette.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppPalette.surface,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppPalette.outlineSoft),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPalette.surface,
        elevation: 2,
        contentTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppPalette.primaryRed.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppPalette.primaryRed,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: AppPalette.navUnselected,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppPalette.primaryRed);
          }
          return const IconThemeData(color: AppPalette.navUnselected);
        }),
      ),
    );
  }

  /// Deprecated: use [lightTheme]. Kept temporarily for incremental migration.
  @Deprecated('Use AppTheme.lightTheme')
  static ThemeData get darkTheme => lightTheme;
}
