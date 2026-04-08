import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/gem_icon.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../../../core/utils/referral_code_format.dart';
import '../services/referral_service.dart';
import '../models/referral_model.dart';
import '../../auth/providers/auth_provider.dart';

/// Bottom sheet wrapper for referral screen.
class ReferralBottomSheet extends StatelessWidget {
  const ReferralBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => const ReferralScreen(),
    );
  }
}

class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  final ReferralService _referralService = ReferralService();
  final TextEditingController _applyCodeController = TextEditingController();
  ReferralData? _data;
  bool _isLoading = true;
  bool _applySubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReferrals();
  }

  @override
  void dispose() {
    _applyCodeController.dispose();
    super.dispose();
  }

  Future<void> _applyLateReferral() async {
    final code = _applyCodeController.text;
    if (!ReferralCodeFormat.isValid(code)) {
      AppToast.showInfo(
        context,
        'Enter a valid code: 6 characters (e.g. JO4832) or 8 (e.g. JOE48392).',
      );
      return;
    }
    setState(() => _applySubmitting = true);
    try {
      await _referralService.applyLateReferralCode(code);
      await ref.read(authProvider.notifier).refreshUser();
      _applyCodeController.clear();
      if (mounted) {
        AppToast.showSuccess(context, 'Referral code applied');
        await _loadReferrals();
      }
    } on ApplyReferralException catch (e) {
      if (mounted) {
        AppToast.showInfo(context, e.message);
      }
    } catch (e) {
      if (mounted) {
        AppToast.showInfo(
          context,
          UserMessageMapper.userMessageFor(
            e,
            fallback: 'Could not apply code. Try again.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _applySubmitting = false);
      }
    }
  }

  Future<void> _loadReferrals() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _referralService.getReferrals();
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = UserMessageMapper.userMessageFor(
            e,
            fallback: 'Couldn\'t load referrals. Please try again.',
          );
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _copyReferralCode(String? code) async {
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      AppToast.showSuccess(
        context,
        'Referral code $code copied to clipboard',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authProvider).user;
    final codeFromUser = user?.referralCode ?? _data?.referralCode;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: ColoredBox(
        color: AppBrandGradients.accountMenuPageBackground,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const BrandSheetHeader(title: 'Referral'),
              Expanded(
              child: _isLoading
                  ? const Center(child: LoadingIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: scheme.error),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load referrals',
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadReferrals,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadReferrals,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // My Referral Code card
                                AppCard(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'My Referral Code',
                                        style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              codeFromUser ?? '—',
                                              style: TextStyle(
                                                color: scheme.onSurface,
                                                fontSize: 28,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 2,
                                              ),
                                            ),
                                          ),
                                          if (codeFromUser != null && codeFromUser.isNotEmpty)
                                            IconButton.filled(
                                              onPressed: () => _copyReferralCode(codeFromUser),
                                              icon: const Icon(Icons.copy),
                                              tooltip: 'Copy',
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Share your code with friends. When they sign up and buy coins worth ₹100+, you earn 60 coins!',
                                        style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                          fontSize: 12,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                AppCard(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Have a code you skipped at sign-up?',
                                        style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'You can apply it once within 24 hours of creating your account and before your first coin purchase.',
                                        style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                          fontSize: 12,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _applyCodeController,
                                        textCapitalization:
                                            TextCapitalization.characters,
                                        maxLength: 8,
                                        decoration: InputDecoration(
                                          hintText: 'e.g. JOE48392 or JO4832',
                                          counterText: '',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      FilledButton(
                                        onPressed:
                                            _applySubmitting ? null : _applyLateReferral,
                                        child: _applySubmitting
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text('Apply referral code'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Referred Users',
                                  style: TextStyle(
                                    color: scheme.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if ((_data?.referrals ?? []).isEmpty)
                                  EmptyState(
                                    icon: Icons.people_outline,
                                    title: 'No referrals yet',
                                    message: 'Share your referral code with friends to get started.',
                                  )
                                else
                                  ...(_data!.referrals).map((entry) => _ReferralListTile(
                                        entry: entry,
                                        scheme: scheme,
                                      )),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _ReferralListTile extends StatelessWidget {
  final ReferralEntry entry;
  final ColorScheme scheme;

  const _ReferralListTile({required this.entry, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            child: Text(
              (entry.name.isNotEmpty ? entry.name[0] : '?').toUpperCase(),
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Joined ${_formatDate(entry.joinedAt)}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: entry.rewardGranted
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry.rewardGranted) ...[
                  const GemIcon(size: 14),
                  const SizedBox(width: 4),
                ],
                Text(
                  entry.rewardGranted ? '60 coins earned' : 'Pending',
                  style: TextStyle(
                    color: entry.rewardGranted
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays > 30) return '${d.day}/${d.month}/${d.year}';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
