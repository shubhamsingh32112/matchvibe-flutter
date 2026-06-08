import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/decorative_asset_image.dart';
import '../constants/help_support_assets.dart';

class HelpRecentPaymentsCard extends StatelessWidget {
  final VoidCallback onTap;

  const HelpRecentPaymentsCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppBrandGradients.accountMenuCardShadow,
              color: scheme.surfaceContainerHigh,
            ),
            padding: const EdgeInsets.fromLTRB(10, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 96,
                  height: 84,
                  child: DecorativeAssetImage(
                    assetPath: HelpSupportAssets.walletCard,
                    width: 96,
                    height: 84,
                    alignment: Alignment.centerLeft,
                    fallbackIcon: Icons.account_balance_wallet_outlined,
                    fallbackIconSize: 40,
                    fallbackIconColor: AppBrandGradients.accountMenuIconTint
                        .withValues(alpha: 0.35),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Payments',
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View all transactions and raise payment complaints',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppPalette.subtitle,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: scheme.surfaceContainerHighest,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onTap,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.chevron_right,
                        size: 22,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
