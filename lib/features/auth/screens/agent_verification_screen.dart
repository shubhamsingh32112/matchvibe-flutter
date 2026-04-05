import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

/// Full-screen gate when the user applied via an agent referral and is awaiting approval.
/// Routing: [SplashScreen] sends users here when `creatorApplicationPending`; after accept,
/// [refreshUser] clears the flag and normal home/creator flows apply.
class AgentVerificationScreen extends ConsumerStatefulWidget {
  const AgentVerificationScreen({super.key});

  @override
  ConsumerState<AgentVerificationScreen> createState() =>
      _AgentVerificationScreenState();
}

class _AgentVerificationScreenState
    extends ConsumerState<AgentVerificationScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await ref.read(authProvider.notifier).refreshUser();
      final u = ref.read(authProvider).user;
      if (!mounted) return;
      if (u?.creatorApplicationPending != true) {
        if (u?.gender == null || u!.gender!.isEmpty) {
          context.go('/gender');
        } else {
          context.go('/home');
        }
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final rejected = user?.creatorApplicationRejected == true;
    final reason = user?.creatorApplicationRejectionReason;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 32),
              Icon(
                rejected ? Icons.info_outline : Icons.hourglass_top_rounded,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                rejected
                    ? 'Creator application update'
                    : 'Creator application pending',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                rejected
                    ? (reason?.isNotEmpty == true
                        ? reason!
                        : 'Your request to become a creator was not approved. You can keep using the app as a member.')
                    : 'Your request to become a creator is being reviewed by your agent. Pull down to refresh status.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              if (!_refreshing)
                FilledButton(
                  onPressed: _refresh,
                  child: const Text('Check status'),
                )
              else
                const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
