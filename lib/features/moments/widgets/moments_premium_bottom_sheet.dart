import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../account/providers/moments_premium_provider.dart';
import '../../account/theme/moments_premium_page_tokens.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../utils/moments_premium_checkout.dart';

class MomentsPremiumBottomSheet extends ConsumerStatefulWidget {
  const MomentsPremiumBottomSheet({super.key, required this.parentRef});

  final WidgetRef parentRef;

  @override
  ConsumerState<MomentsPremiumBottomSheet> createState() =>
      _MomentsPremiumBottomSheetState();
}

class _MomentsPremiumBottomSheetState
    extends ConsumerState<MomentsPremiumBottomSheet> {
  bool _checkingOut = false;

  static const _features = <({IconData icon, String title, String subtitle})>[
    (
      icon: Icons.all_inclusive,
      title: 'Unlimited Moments',
      subtitle: 'Enjoy unlimited access to all premium moments.',
    ),
    (
      icon: Icons.verified_user_outlined,
      title: 'Verified Creators',
      subtitle: 'Only trusted and verified creators.',
    ),
    (
      icon: Icons.bolt_outlined,
      title: 'First Access to Stories',
      subtitle: 'Watch stories before regular users.',
    ),
  ];

  Future<void> _unlock() async {
    if (_checkingOut) return;
    setState(() => _checkingOut = true);
    try {
      await launchMomentsPremiumCheckout(context, widget.parentRef);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(momentsPremiumPlansProvider);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: MomentsPremiumPageTokens.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
        child: plansAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: LoadingIndicator(color: MomentsPremiumPageTokens.accentPink),
            ),
          ),
          error: (_, __) => const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Could not load plans'),
          ),
          data: (response) {
            final plan = response.defaultPlan ??
                (response.activePlans.isNotEmpty ? response.activePlans.first : null);
            final priceLabel = plan != null ? '₹${plan.priceInr}' : '₹99';

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: MomentsPremiumPageTokens.ctaGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: MomentsPremiumPageTokens.accentPurple
                                .withValues(alpha: 0.45),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Moments Premium',
                                style: GoogleFonts.lexend(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.workspace_premium,
                                color: MomentsPremiumPageTokens.accentGold,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Unlock exclusive photos, videos and stories from verified creators.',
                            style: GoogleFonts.lexend(
                              color: MomentsPremiumPageTokens.textMuted,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ..._features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(f.icon, color: MomentsPremiumPageTokens.accentPink, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.title,
                                style: GoogleFonts.lexend(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                f.subtitle,
                                style: GoogleFonts.lexend(
                                  color: MomentsPremiumPageTokens.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: MomentsPremiumPageTokens.ctaGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _checkingOut ? null : _unlock,
                        borderRadius: BorderRadius.circular(16),
                        child: Center(
                          child: _checkingOut
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.workspace_premium,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Unlock Now for $priceLabel',
                                      style: GoogleFonts.lexend(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    '🔒 Cancel anytime. No hidden charges.',
                    style: GoogleFonts.lexend(
                      color: MomentsPremiumPageTokens.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
