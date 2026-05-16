import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_modal_dialog.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/referral_service.dart';

/// Confirms applying an agency referral code for a logged-in user or host.
Future<void> presentAgencyReferralApplyDialog(
  BuildContext context,
  WidgetRef ref, {
  required String referralCode,
  required String? agencyDisplayName,
}) async {
  await showAppModalDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return _AgencyReferralApplyDialogBody(
        referralCode: referralCode,
        agencyDisplayName: agencyDisplayName,
        onDismiss: () => Navigator.of(dialogContext).pop(),
      );
    },
  );
}

class _AgencyReferralApplyDialogBody extends ConsumerStatefulWidget {
  final String referralCode;
  final String? agencyDisplayName;
  final VoidCallback onDismiss;

  const _AgencyReferralApplyDialogBody({
    required this.referralCode,
    required this.agencyDisplayName,
    required this.onDismiss,
  });

  @override
  ConsumerState<_AgencyReferralApplyDialogBody> createState() =>
      _AgencyReferralApplyDialogBodyState();
}

class _AgencyReferralApplyDialogBodyState
    extends ConsumerState<_AgencyReferralApplyDialogBody> {
  final _referralService = ReferralService();
  bool _applying = false;

  Future<void> _apply() async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      await _referralService.applyAgencyHostReferral(widget.referralCode);
      if (!mounted) return;
      await ref.read(authProvider.notifier).refreshUser();
      if (!mounted) return;
      widget.onDismiss();
      AppToast.showSuccess(
        context,
        'Request sent to the agency for approval',
      );
    } on ApplyReferralException catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.message);
      setState(() => _applying = false);
    } catch (_) {
      if (!mounted) return;
      AppToast.showError(
        context,
        'Could not apply referral code. Try again.',
      );
      setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final agencyLabel = (widget.agencyDisplayName?.trim().isNotEmpty == true)
        ? widget.agencyDisplayName!.trim()
        : 'this agency';

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Join agency?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Apply referral code ${widget.referralCode} to join $agencyLabel. '
              'The agency will review your request.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _applying ? null : widget.onDismiss,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _applying ? null : _apply,
                    child: _applying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Apply'),
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
