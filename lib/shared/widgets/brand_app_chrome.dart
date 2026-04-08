import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../styles/app_brand_styles.dart';
import 'gem_icon.dart';

/// App bar matching Account tab: purple gradient, light status bar, white foreground.
AppBar buildBrandAppBar(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
  Widget? leading,
  bool automaticallyImplyLeading = true,
  bool centerTitle = false,
}) {
  final theme = Theme.of(context);
  return AppBar(
    leading: leading,
    automaticallyImplyLeading: automaticallyImplyLeading && leading == null,
    centerTitle: centerTitle,
    title: Text(title),
    actions: actions,
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    foregroundColor: Colors.white,
    iconTheme: const IconThemeData(color: Colors.white),
    titleTextStyle: theme.textTheme.titleLarge?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
    systemOverlayStyle: SystemUiOverlayStyle.light,
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: AppBrandGradients.accountMenuHeaderGradient,
      ),
    ),
  );
}

/// Purple gradient title strip for modal bottom sheets (Account tab style).
class BrandSheetHeader extends StatelessWidget {
  final String title;
  final List<Widget>? trailing;

  const BrandSheetHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppBrandGradients.accountMenuHeaderGradient,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (trailing != null) ...trailing!,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact coin balance for gradient app bars / sheet headers.
class BrandHeaderCoinsChip extends StatelessWidget {
  final int coins;

  const BrandHeaderCoinsChip({super.key, required this.coins});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GemIcon(size: 18),
            const SizedBox(width: 6),
            Text(
              '$coins',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
