import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../styles/app_brand_styles.dart';

class ComingSoonPlaceholder extends StatelessWidget {
  final IconData? icon;
  final String? assetIconPath;
  final String title;
  final String subtitle;
  final bool isLocked;

  const ComingSoonPlaceholder({
    super.key,
    this.icon,
    this.assetIconPath,
    required this.title,
    this.subtitle = 'We\'re working on something exciting. Check back soon!',
    this.isLocked = false,
  }) : assert(
          icon != null || assetIconPath != null,
          'Provide icon or assetIconPath',
        );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (assetIconPath != null)
                  Opacity(
                    opacity: isLocked ? 0.55 : 1.0,
                    child: Image.asset(
                      assetIconPath!,
                      width: 88,
                      height: 88,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  )
                else
                  Opacity(
                    opacity: isLocked ? 0.85 : 1.0,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppBrandGradients.accountMenuHeaderGradient,
                      ),
                      child: Icon(icon, size: 44, color: Colors.white),
                    ),
                  ),
                if (isLocked)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppPalette.onSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppPalette.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppPalette.subtitle,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
