import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App-wide dark palette.
class AppPalette {
  AppPalette._();

  static const Color primaryRed = Color(0xFFD32F2F);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFF121212);
  static const Color onSurface = Color(0xFFFFFFFF);
  static const Color subtitle = Color(0xB3FFFFFF);
  static const Color beige = Color(0xFF1A1A1A);
  static const Color beigeAlt = Color(0xFF1E1E1E);
  static const Color outline = Color(0xFF2A2A2A);
  static const Color outlineSoft = Color(0xFF333333);
  static const Color navUnselected = Color(0xB3FFFFFF);
  static const Color emptyIcon = Color(0xFF616161);
  static const Color success = Color(0xFF66BB6A);
  static const Color warning = Color(0xFFF9A825);
}

class AppTheme {
  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme scheme,
    required TextTheme textTheme,
    required String? fontFamily,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      fontFamily: fontFamily,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHigh,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
        hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5)),
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
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerHighest,
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
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppPalette.primaryRed.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: AppPalette.primaryRed,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: fontFamily,
            );
          }
          return TextStyle(
            color: AppPalette.navUnselected,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFamily: fontFamily,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppPalette.primaryRed);
          }
          return IconThemeData(color: AppPalette.navUnselected);
        }),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline),
      listTileTheme: ListTileThemeData(
        textColor: scheme.onSurface,
        iconColor: scheme.onSurface,
      ),
    );
  }

  /// Canonical dark theme for the entire app.
  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppPalette.primaryRed,
        brightness: Brightness.dark,
      ),
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
      surfaceContainerLowest: const Color(0xFF0D0D0D),
      surfaceContainerLow: const Color(0xFF141414),
      surfaceContainer: const Color(0xFF181818),
      surfaceContainerHigh: const Color(0xFF1E1E1E),
      surfaceContainerHighest: const Color(0xFF252525),
      onSurfaceVariant: const Color(0xB3FFFFFF),
    );

    final textTheme = GoogleFonts.lexendTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ).apply(
      bodyColor: AppPalette.onSurface,
      displayColor: AppPalette.onSurface,
    );

    return _buildTheme(
      brightness: Brightness.dark,
      scheme: scheme,
      textTheme: textTheme,
      fontFamily: GoogleFonts.lexend().fontFamily,
    );
  }

  /// Frozen inherited Material theme for the VIP subscription tab only.
  static ThemeData get vipInheritedTheme {
    const lightSurface = Color(0xFFFFFFFF);
    const lightOnSurface = Color(0xFF1A1A1A);

    final scheme = const ColorScheme(
      brightness: Brightness.light,
      primary: AppPalette.primaryRed,
      onPrimary: AppPalette.onPrimary,
      secondary: Color(0xFFF5F5DC),
      onSecondary: lightOnSurface,
      error: AppPalette.primaryRed,
      onError: AppPalette.onPrimary,
      surface: lightSurface,
      onSurface: lightOnSurface,
      outline: Color(0xFFE0E0E0),
      outlineVariant: Color(0xFFECECEC),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFFAF8F5),
      surfaceContainer: Color(0xFFF7EFE5),
      surfaceContainerHigh: Color(0xFFF2EDE6),
      surfaceContainerHighest: Color(0xFFE8E3DB),
    );

    final textTheme = GoogleFonts.lexendTextTheme(
      ThemeData(brightness: Brightness.light).textTheme,
    );

    return _buildTheme(
      brightness: Brightness.light,
      scheme: scheme,
      textTheme: textTheme,
      fontFamily: GoogleFonts.lexend().fontFamily,
    );
  }

  /// Deprecated: app uses [darkTheme].
  @Deprecated('Use AppTheme.darkTheme')
  static ThemeData get lightTheme => darkTheme;
}
