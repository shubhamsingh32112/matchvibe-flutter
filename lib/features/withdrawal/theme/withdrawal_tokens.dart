import 'package:flutter/material.dart';

import '../../creator/theme/creator_home_tokens.dart';
import '../../../shared/styles/app_brand_styles.dart';

/// Visual tokens for the creator withdrawal screen (aligned with creator home).
class WithdrawalTokens {
  const WithdrawalTokens._();

  static const Color primaryPurple = CreatorHomeTokens.primaryPurple;
  static const Color labelGrey = CreatorHomeTokens.labelGrey;
  static const Color bannerLavender = CreatorHomeTokens.bannerLavender;
  static const Color infoStripBg = Color(0xFFF5F5F8);
  static const Color borderGrey = Color(0xFFE6E6EB);
  static const Color valueDark = Color(0xFF1B1B33);
  static const Color secureGreen = CreatorHomeTokens.completedGreen;
  static const Color instantBlue = CreatorHomeTokens.statBlue;

  static const double cardRadius = 20;
  static const double fieldRadius = 12;
  static const double submitRadius = 14;

  static const LinearGradient submitGradient = CreatorHomeTokens.withdrawalGradient;

  static BoxDecoration cardDecoration({Color? color}) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(cardRadius),
      boxShadow: AppBrandGradients.accountMenuCardShadow,
    );
  }

  static InputDecoration fieldDecoration({
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: const TextStyle(color: labelGrey, fontSize: 14),
      hintStyle: TextStyle(color: labelGrey.withValues(alpha: 0.6), fontSize: 14),
      prefixIcon: prefixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: const BorderSide(color: borderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: const BorderSide(color: primaryPurple, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  static Widget prefixIconCircle(Widget icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: primaryPurple.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: icon,
      ),
    );
  }
}
