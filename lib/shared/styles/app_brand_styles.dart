import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Centralized brand gradients and decorative styles used across the app.
class AppBrandGradients {
  const AppBrandGradients._();

  /// Global brand background — dark gradient.
  static const LinearGradient appBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF121212),
      Color(0xFF1A1A1A),
    ],
  );

  static const LinearGradient accountBackground = appBackground;

  /// Pre-connect video call card (dial / incoming).
  static const LinearGradient callDialCard = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1E1A2E),
      Color(0xFF121218),
    ],
  );

  /// Soft separation for frosted-style cards.
  static LinearGradient get frostedCard => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppPalette.surface,
          AppPalette.beige.withValues(alpha: 0.85),
        ],
      );

  /// Avatar ring — red accent.
  static const LinearGradient avatarRing = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEF5350),
      AppPalette.primaryRed,
    ],
  );

  /// Creator role pill — warm amber/orange.
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

  /// VIP membership badge — gold premium accent.
  static const Color vipBadgeGold = Color(0xFFFFB300);

  static const LinearGradient vipBadgeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFD54F),
      Color(0xFFFF8F00),
    ],
  );

  static const Color avatarCarouselSelectedBorder = AppPalette.primaryRed;

  static Color get avatarCarouselUnselectedBorder =>
      AppPalette.outline.withValues(alpha: 0.8);

  static const double avatarCarouselSelectedBorderWidth = 3.0;

  static const double avatarCarouselUnselectedBorderWidth = 1.5;

  static const BoxShadow avatarCarouselGlow = BoxShadow(
    color: Color(0x40D32F2F),
    blurRadius: 18,
    spreadRadius: 2,
  );

  static const LinearGradient walletBackground = appBackground;

  /// Wallet promo — dark red tint.
  static const LinearGradient walletPromoBanner = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2A1518),
      Color(0xFF1A1A1A),
    ],
  );

  static const Color walletScaffoldBackground = AppPalette.surface;

  static const Color walletRefreshIndicatorBackground = AppPalette.primaryRed;

  static const LinearGradient walletCoinGold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFE082),
      Color(0xFFFFB300),
    ],
  );

  static const Color walletPromoIcon = AppPalette.primaryRed;

  static const Color walletEarningsHighlight = Color(0xFFFFB74D);

  static const Color walletOnGold = Color(0xFFFFFFFF);

  static LinearGradient userCardOverlay(ColorScheme scheme) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.0),
          Colors.black.withValues(alpha: 0.45),
        ],
      );

  static const Color accountMenuPageBackground = Color(0xFF0D0D0D);

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

  static const Color accountMenuIconTint = Color(0xFFCE93D8);

  static List<BoxShadow> get accountMenuCardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.32),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static const LinearGradient creatorProfileVideoCallGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFFFF4081),
      Color(0xFFFF9800),
    ],
  );

  static const Color creatorProfileActiveTabColor = Color(0xFFFF4081);

  static const Color creatorProfileInactiveTabColor = Color(0xFF7C4DFF);

  static const Color creatorProfileAccentPink = Color(0xFFFF4081);

  static const Color momentsPageBackground = Color(0xFF0D0D0D);

  static const Color momentsTitleColor = Color(0xFFFFFFFF);

  static const Color momentsSubtitleColor = Color(0xB3FFFFFF);

  static const Color momentsTabActiveColor = Color(0xFFFF4081);

  static const Color momentsTabInactiveColor = Color(0xB3FFFFFF);

  static const Color momentsTrophyBackground = Color(0xFF1E1E1E);

  static const LinearGradient momentsStoryRingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF4081),
      Color(0xFF7C4DFF),
      Color(0xFFFF9800),
    ],
  );

  /// Purple → pink gradient for moment viewer Chat / Video Call buttons.
  static const LinearGradient momentsViewerActionGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF7B2FF7),
      Color(0xFFF13DD4),
    ],
  );

  static const LinearGradient momentsLiveBadgeGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFFFF4081),
      Color(0xFFFF6B9D),
    ],
  );

  static const double momentsCardRadius = 20;

  static List<BoxShadow> get momentsCardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.32),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
}
