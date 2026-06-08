import 'package:flutter/material.dart';

import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/decorative_asset_image.dart';
import '../constants/become_creator_assets.dart';

/// Become a Creator icon for account menu tiles and inline labels.
class BecomeCreatorIcon extends StatelessWidget {
  final double size;

  const BecomeCreatorIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return DecorativeAssetImage(
      assetPath: BecomeCreatorAssets.menuIcon,
      width: size,
      height: size,
      fallbackIcon: Icons.auto_awesome_outlined,
      fallbackIconSize: size,
      fallbackIconColor: AppBrandGradients.accountMenuIconTint,
    );
  }
}
