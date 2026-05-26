import 'package:flutter/material.dart';

/// Renders a PNG decorative illustration with correct alpha compositing.
///
/// Wraps [Image.asset] in a transparent [Material] so transparent pixels are
/// not composited against an opaque black surface on some devices.
class DecorativeAssetImage extends StatelessWidget {
  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final IconData fallbackIcon;
  final double fallbackIconSize;
  final Color? fallbackIconColor;

  const DecorativeAssetImage({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.fallbackIcon = Icons.image_outlined,
    this.fallbackIconSize = 48,
    this.fallbackIconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) => Icon(
          fallbackIcon,
          size: fallbackIconSize,
          color: fallbackIconColor ?? Colors.grey.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
