import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/widgets/app_nav_assets.dart';
import '../../../app/widgets/app_nav_destinations.dart';
import '../../../app/widgets/main_layout.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../../../shared/widgets/coming_soon_placeholder.dart';

class VipScreen extends ConsumerWidget {
  const VipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider.select((s) => s.user?.role));
    if (AppNavDestinations.isCreatorOrAdmin(role)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/recent');
      });
      return const SizedBox.shrink();
    }

    return MainLayout(
      selectedIndex: AppNavDestinations.centerIndex,
      appBar: buildBrandAppBar(context, title: 'VIP'),
      child: const ComingSoonPlaceholder(
        assetIconPath: AppNavAssets.vipIcon,
        isLocked: true,
        title: 'Locked',
        subtitle:
            'VIP is locked right now. Subscribe to unlock premium perks when it becomes available.',
      ),
    );
  }
}
