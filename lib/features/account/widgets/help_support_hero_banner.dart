import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/decorative_asset_image.dart';
import '../constants/help_support_assets.dart';

class HelpSupportHeroBanner extends StatelessWidget {
  const HelpSupportHeroBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topInset + AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 18, 16, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFBFE),
              Color(0xFFF3E5F5),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppBrandGradients.accountMenuCardShadow,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -4,
              top: -10,
              child: _DecorativeCircle(
                size: 44,
                color: const Color(0xFFEDE7F6).withValues(alpha: 0.7),
              ),
            ),
            Positioned(
              right: 28,
              bottom: -4,
              child: _DecorativeCircle(
                size: 20,
                color: const Color(0xFFF3E5F5).withValues(alpha: 0.9),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 108,
                  height: 108,
                  child: DecorativeAssetImage(
                    assetPath: HelpSupportAssets.headsetHero,
                    width: 108,
                    height: 108,
                    fallbackIcon: Icons.headset_mic_outlined,
                    fallbackIconSize: 56,
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
                        'Help & Support',
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A1A1A),
                                ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4, bottom: 8),
                        width: 36,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppBrandGradients.accountMenuIconTint,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Text(
                        'We\'re here to help you 24/7 💜',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppBrandGradients.accountMenuIconTint,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _DecorativeCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
