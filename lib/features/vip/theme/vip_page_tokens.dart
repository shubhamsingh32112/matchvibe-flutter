import 'package:flutter/material.dart';

import '../../../shared/styles/app_brand_styles.dart';

/// Visual tokens for the VIP subscription marketing page.
abstract final class VipPageTokens {
  static const Color pageBackgroundTop = Color(0xFF2A1060);
  static const Color pageBackgroundBottom = Color(0xFF0A0618);
  static const Color surface = Color(0xFF3D1F6E);
  static const Color surfaceElevated = Color(0xFF4A2780);
  static const Color borderGold = Color(0xFFFFD54F);
  static const Color textPrimary = Colors.white;
  static const Color textMuted = Color(0xFFB8A4D9);
  static const Color textGold = Color(0xFFFFD54F);
  static const Color accentPink = Color(0xFFFF4081);
  static const Color checkGreen = Color(0xFF66BB6A);

  static const LinearGradient pageBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [pageBackgroundTop, pageBackgroundBottom],
  );

  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFFFFD54F),
      Color(0xFFFF8F00),
    ],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4E2A88),
      Color(0xFF32165C),
    ],
  );

  static LinearGradient get goldBadgeGradient =>
      AppBrandGradients.vipBadgeGradient;

  static const double horizontalPadding = 18;
  static const double cardRadius = 18;
  static const double pillRadius = 24;

  static List<BoxShadow> get heroGlow => [
        BoxShadow(
          color: borderGold.withValues(alpha: 0.25),
          blurRadius: 32,
          spreadRadius: 4,
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
}
