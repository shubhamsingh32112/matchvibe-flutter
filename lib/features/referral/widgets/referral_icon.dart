import 'package:flutter/material.dart';

import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/decorative_asset_image.dart';
import '../constants/referral_assets.dart';

/// Referral icon for account menu tiles and inline labels.
class ReferralIcon extends StatelessWidget {
  final double size;

  const ReferralIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return DecorativeAssetImage(
      assetPath: ReferralAssets.menuIcon,
      width: size,
      height: size,
      fallbackIcon: Icons.card_giftcard_outlined,
      fallbackIconSize: size,
      fallbackIconColor: AppBrandGradients.accountMenuIconTint,
    );
  }
}
