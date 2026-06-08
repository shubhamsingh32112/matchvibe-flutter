import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/styles/app_brand_styles.dart';

/// Reference-inspired purple/pink palette scoped to creator home only.
class CreatorHomeTokens {
  const CreatorHomeTokens._();

  static const Color pageBackground = AppPalette.surface;
  static const Color primaryPurple = Color(0xFF7B2CBF);
  static const Color pinkAccent = Color(0xFFFF4081);
  static const Color pinkAccentDeep = Color(0xFFFF4D6D);
  static const Color orangeAccent = Color(0xFFFF8A50);
  static const Color labelGrey = Color(0xFF8E8E93);
  static const Color statBlue = Color(0xFF5C6BC0);
  static const Color statYellow = Color(0xFFF9A825);
  static const Color trophyGold = Color(0xFFFFB300);
  static const Color bannerLavender = AppPalette.beigeAlt;
  static const Color completedGreen = Color(0xFF2E7D32);

  static const double cardRadius = 16;
  static const double sectionPaddingH = 16;
  static const double sectionSpacing = 12;

  static const LinearGradient withdrawalGradient = LinearGradient(
    colors: [pinkAccentDeep, orangeAccent],
  );

  static const LinearGradient taskCompletedGradient = LinearGradient(
    colors: [pinkAccentDeep, orangeAccent],
  );

  static const LinearGradient taskInProgressGradient = LinearGradient(
    colors: [primaryPurple, Color(0xFF5C6BC0)],
  );

  static List<BoxShadow> get cardShadow => AppBrandGradients.momentsCardShadow;

  static BoxDecoration cardDecoration({Color? color}) {
    return BoxDecoration(
      color: color ?? AppPalette.beigeAlt,
      borderRadius: BorderRadius.circular(cardRadius),
      boxShadow: cardShadow,
    );
  }
}
