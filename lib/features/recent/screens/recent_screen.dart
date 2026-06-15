import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/widgets/app_nav_index.dart';
import '../../../app/widgets/main_layout.dart';
import '../widgets/recent_calls_tab.dart';

class RecentScreen extends ConsumerWidget {
  const RecentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MainLayout(
      selectedIndex: appNavSelectedIndex(ref, '/recent'),
      child: const RecentCallsTab(),
    );
  }
}
