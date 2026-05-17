import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/brand_app_chrome.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/providers/auth_provider.dart';
import '../utils/host_onboarding_routes.dart';

class HostApplicationPendingScreen extends ConsumerStatefulWidget {
  const HostApplicationPendingScreen({super.key});

  @override
  ConsumerState<HostApplicationPendingScreen> createState() =>
      _HostApplicationPendingScreenState();
}

class _HostApplicationPendingScreenState
    extends ConsumerState<HostApplicationPendingScreen> {
  bool _refreshing = false;

  Future<void> _refreshStatus() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(authProvider.notifier).refreshUser();
      if (!mounted) return;
      final user = ref.read(authProvider).user;
      final next = hostOnboardingRedirectPath(user);
      if (next == null || next == '/host-application-pending') {
        return;
      }
      context.go(next);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      padded: false,
      appBar: buildBrandAppBar(
        context,
        title: 'Host application',
        automaticallyImplyLeading: false,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Icon(Icons.hourglass_top_rounded, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 20),
            Text(
              'Waiting for agency approval',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your request to become a host is being reviewed. Pull to refresh or tap below after your agency approves you.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            FilledButton(
              onPressed: _refreshing ? null : _refreshStatus,
              child: _refreshing
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: LoadingIndicator(size: 22),
                    )
                  : const Text('Check status'),
            ),
          ],
        ),
      ),
    );
  }
}
