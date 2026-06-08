import 'package:flutter/material.dart';

import '../../../shared/widgets/decorative_asset_image.dart';
import '../theme/vip_page_tokens.dart';

class VipBenefitIcon extends StatelessWidget {
  const VipBenefitIcon({
    super.key,
    this.assetPath,
    required this.fallbackIcon,
    required this.size,
  });

  final String? assetPath;
  final IconData fallbackIcon;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (assetPath == null) {
      return Icon(
        fallbackIcon,
        color: VipPageTokens.textGold,
        size: size * 0.62,
      );
    }

    return DecorativeAssetImage(
      assetPath: assetPath!,
      width: size,
      height: size,
      fit: BoxFit.contain,
      fallbackIcon: fallbackIcon,
      fallbackIconSize: size * 0.62,
      fallbackIconColor: VipPageTokens.textGold,
    );
  }
}
