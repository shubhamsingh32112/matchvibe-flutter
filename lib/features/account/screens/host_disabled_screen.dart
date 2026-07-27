import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/brand_app_chrome.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../account/utils/creator_whatsapp_launcher.dart';
import '../../auth/providers/auth_provider.dart';

/// Full-screen lock when superadmin has deactivated this host account.
class HostDisabledScreen extends ConsumerStatefulWidget {
  const HostDisabledScreen({super.key});

  @override
  ConsumerState<HostDisabledScreen> createState() => _HostDisabledScreenState();
}

class _HostDisabledScreenState extends ConsumerState<HostDisabledScreen> {
  bool _openingWhatsapp = false;
  bool _loggingOut = false;

  Future<void> _contactAdmin() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    setState(() => _openingWhatsapp = true);
    try {
      final opened = await CreatorWhatsappLauncher.launchHostDisabledChat(
        userId: user.id,
        hostName: user.name ?? user.username ?? 'Host',
      );
      if (!mounted) return;
      if (!opened) {
        AppToast.showError(
          context,
          'Could not open WhatsApp. Please try again later.',
        );
      }
    } finally {
      if (mounted) setState(() => _openingWhatsapp = false);
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await ref.read(authProvider.notifier).signOut();
      if (!mounted) return;
      context.go('/login');
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      padded: false,
      appBar: buildBrandAppBar(
        context,
        title: 'Account deactivated',
        automaticallyImplyLeading: false,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Icon(
              Icons.block_rounded,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 20),
            Text(
              'Your host account is deactivated',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'You cannot use the host app until a super admin reactivates your account. '
              'Contact your BD for help, or reach out to admin on WhatsApp.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Text(
              'Contact your BD',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Please reach out to your business developer for assistance.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            FilledButton(
              onPressed: _openingWhatsapp ? null : _contactAdmin,
              child: _openingWhatsapp
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Contact admin'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loggingOut ? null : _logout,
              child: _loggingOut
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}
