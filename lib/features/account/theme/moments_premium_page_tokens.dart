import 'package:flutter/material.dart';

/// Visual tokens for the Moments Premium subscription page.
abstract final class MomentsPremiumPageTokens {
  static const Color pageBackground = Color(0xFF050505);
  static const Color surface = Color(0xFF141018);
  static const Color surfaceElevated = Color(0xFF1E1528);
  static const Color textPrimary = Colors.white;
  static const Color textMuted = Color(0xFFB8A4D9);
  static const Color accentPink = Color(0xFFFF4B91);
  static const Color accentPurple = Color(0xFF7B2CBF);
  static const Color accentGold = Color(0xFFFFD54F);
  static const Color checkPurple = Color(0xFFCE93D8);

  static const LinearGradient pageGlow = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF2A1060),
      Color(0xFF050505),
      Color(0xFF050505),
    ],
    stops: [0.0, 0.35, 1.0],
  );

  static const LinearGradient premiumTextGradient = LinearGradient(
    colors: [accentPurple, accentPink],
  );

  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFFFF4B91),
      Color(0xFF7B2CBF),
      Color(0xFF5B2EFF),
    ],
  );

  static const LinearGradient badgeGradient = LinearGradient(
    colors: [accentPink, accentPurple],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2A1538),
      Color(0xFF120A1C),
    ],
  );

  static const double horizontalPadding = 16;
  static const double cardRadius = 16;
  static const double pillRadius = 20;

  static List<BoxShadow> selectedCardGlow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.55),
          blurRadius: 18,
          spreadRadius: 1,
        ),
        BoxShadow(
          color: color.withValues(alpha: 0.25),
          blurRadius: 32,
          spreadRadius: 4,
        ),
      ];
}
