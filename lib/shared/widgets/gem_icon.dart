import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Reusable gem icon widget that displays the coin/gem SVG.
/// 
/// This widget is used throughout the app to display coins consistently.
/// The gem icon always displays in golden color to match the brand.
class GemIcon extends StatelessWidget {
  final double size;
  final Color? color; // Deprecated: kept for API compatibility but ignored
  
  const GemIcon({
    super.key,
    this.size = 20,
    this.color, // Ignored - always uses golden color
  });

  /// Golden color matching the wallet coin gold gradient
  static const Color _goldenColor = Color(0xFFFFD65A);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        'lib/assets/gem.svg',
        width: size,
        height: size,
        // Always apply golden color filter to ensure consistent golden appearance
        colorFilter: const ColorFilter.mode(_goldenColor, BlendMode.srcIn),
      ),
    );
  }
}
