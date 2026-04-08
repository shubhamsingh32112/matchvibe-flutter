import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Centralized brand gradients and decorative styles used across the app.
///
/// Light theme: white/beige bases, red accent — no purple or dark backgrounds.
class AppBrandGradients {
  const AppBrandGradients._();

  /// Global brand background — subtle white to warm beige.
  static const LinearGradient appBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFFFF),
      AppPalette.beige,
    ],
  );

  static const LinearGradient accountBackground = appBackground;

  /// Soft separation for frosted-style cards (light mode).
  static LinearGradient get frostedCard => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppPalette.surface,
          AppPalette.beige.withValues(alpha: 0.85),
        ],
      );

  /// Avatar ring — red accent (replaces purple).
  static const LinearGradient avatarRing = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEF5350),
      AppPalette.primaryRed,
    ],
  );

  /// Creator role pill — warm amber/orange (status, not primary CTA).
  static LinearGradient get creatorBadge => LinearGradient(
        colors: [
          Colors.amber[600]!,
          Colors.orange[600]!,
        ],
      );

  /// Admin role pill — red tones aligned with brand accent.
  static const LinearGradient adminBadge = LinearGradient(
    colors: [
      Color(0xFFE53935),
      AppPalette.primaryRed,
    ],
  );

  static const Color avatarCarouselSelectedBorder = AppPalette.primaryRed;

  static Color get avatarCarouselUnselectedBorder =>
      AppPalette.outline.withValues(alpha: 0.8);

  static const double avatarCarouselSelectedBorderWidth = 3.0;

  static const double avatarCarouselUnselectedBorderWidth = 1.5;

  /// Must remain `const` for use in const widget lists (e.g. edit profile).
  static const BoxShadow avatarCarouselGlow = BoxShadow(
    color: Color(0x40D32F2F),
    blurRadius: 18,
    spreadRadius: 2,
  );

  static const LinearGradient walletBackground = appBackground;

  /// Wallet promo — soft red tint (replaces blue).
  static const LinearGradient walletPromoBanner = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFEBEE),
      AppPalette.beige,
    ],
  );

  static const Color walletScaffoldBackground = AppPalette.surface;

  static const Color walletRefreshIndicatorBackground = AppPalette.primaryRed;

  /// Coin emphasis — muted gold on light UI.
  static const LinearGradient walletCoinGold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFE082),
      Color(0xFFFFB300),
    ],
  );

  static const Color walletPromoIcon = AppPalette.primaryRed;

  static const Color walletEarningsHighlight = Color(0xFFE65100);

  static const Color walletOnGold = Color(0xFF1A1A1A);

  /// Light scrim over card images for readable white/light text; darkens photo bottom slightly.
  static LinearGradient userCardOverlay(ColorScheme scheme) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.0),
          Colors.black.withValues(alpha: 0.45),
        ],
      );

  // ── Account menu tab only (reference UI); does not change global theme ──

  static const Color accountMenuPageBackground = Color(0xFFF3F0F7);

  /// Video call FAB on user home creator cards.
  static const Color userHomeVideoCall = Color(0xFF6C4EF3);

  static const LinearGradient accountMenuHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF7C4DFF),
      Color(0xFF5E35B1),
    ],
  );

  static const LinearGradient accountMenuCtaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF7C4DFF),
      Color(0xFF448AFF),
    ],
  );

  static const Color accountMenuIconTint = Color(0xFF6A1B9A);

  static List<BoxShadow> get accountMenuCardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
}
