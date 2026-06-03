import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/widgets/app_nav_destinations.dart';
import '../../../app/widgets/main_layout.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/recent_calls_tab.dart';

class RecentScreen extends ConsumerWidget {
  const RecentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider.select((s) => s.user?.role));
    if (role == 'user') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/chat-list?tab=calls');
        }
      });
      return const SizedBox.shrink();
    }

    return const MainLayout(
      selectedIndex: AppNavDestinations.centerIndex,
      child: RecentCallsTab(),
    );
  }
}
