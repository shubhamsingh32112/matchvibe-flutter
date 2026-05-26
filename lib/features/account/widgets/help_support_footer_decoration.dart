import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/decorative_asset_image.dart';
import '../constants/help_support_assets.dart';

class HelpSupportFooterDecoration extends StatelessWidget {
  const HelpSupportFooterDecoration({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      child: Center(
        child: DecorativeAssetImage(
          assetPath: HelpSupportAssets.footerEnvelope,
          height: 148,
          fallbackIcon: Icons.mail_outline,
          fallbackIconSize: 56,
          fallbackIconColor:
              AppBrandGradients.accountMenuIconTint.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}
