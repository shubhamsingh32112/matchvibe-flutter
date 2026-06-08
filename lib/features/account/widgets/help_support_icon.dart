import 'package:flutter/material.dart';

import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/decorative_asset_image.dart';
import '../constants/help_support_assets.dart';

/// Help & Support icon for account menu tiles and inline labels.
class HelpSupportIcon extends StatelessWidget {
  final double size;

  const HelpSupportIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return DecorativeAssetImage(
      assetPath: HelpSupportAssets.headsetHero,
      width: size,
      height: size,
      fallbackIcon: Icons.headset_mic_outlined,
      fallbackIconSize: size,
      fallbackIconColor: AppBrandGradients.accountMenuIconTint,
    );
  }
}
