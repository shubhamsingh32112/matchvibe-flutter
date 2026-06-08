import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../styles/app_brand_styles.dart';

/// Coin / balance icon used in the app bar, account section, and creator pricing.
class GemIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const GemIcon({
    super.key,
    this.size = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppConstants.coinsIconAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Icon(
        Icons.diamond_outlined,
        size: size,
        color: color ?? AppBrandGradients.accountMenuIconTint,
      ),
    );
  }
}
