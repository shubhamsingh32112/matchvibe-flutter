import 'package:flutter/material.dart';
import '../styles/app_brand_styles.dart';

/// Coin / balance icon: same outlined diamond and tint as Account → Explore → Coins.
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
    return Icon(
      Icons.diamond_outlined,
      size: size,
      color: color ?? AppBrandGradients.accountMenuIconTint,
    );
  }
}
