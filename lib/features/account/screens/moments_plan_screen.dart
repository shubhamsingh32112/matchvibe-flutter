import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/app_nav_destinations.dart';
import '../../../app/widgets/app_nav_index.dart';
import '../../../app/widgets/main_layout.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../../auth/providers/auth_provider.dart';
import '../../video/providers/call_billing_provider.dart';
import '../../video/providers/call_billing_selectors.dart';

class MomentsPlanOption {
  const MomentsPlanOption({
    required this.id,
    required this.label,
    required this.priceInr,
    required this.durationDays,
    this.badge,
  });

  final String id;
  final String label;
  final int priceInr;
  final int durationDays;
  final String? badge;
}

const _momentsPlans = <MomentsPlanOption>[
  MomentsPlanOption(id: 'moments_3d', label: '3 Days', priceInr: 29, durationDays: 3),
  MomentsPlanOption(id: 'moments_7d', label: '7 Days', priceInr: 99, durationDays: 7),
  MomentsPlanOption(
    id: 'moments_1m',
    label: '1 Month',
    priceInr: 199,
    durationDays: 30,
    badge: 'Popular',
  ),
  MomentsPlanOption(
    id: 'moments_3m',
    label: '3 Months',
    priceInr: 299,
    durationDays: 90,
    badge: 'Best Value',
  ),
];

class MomentsPlanScreen extends ConsumerStatefulWidget {
  const MomentsPlanScreen({super.key});

  @override
  ConsumerState<MomentsPlanScreen> createState() => _MomentsPlanScreenState();
}

class _MomentsPlanScreenState extends ConsumerState<MomentsPlanScreen> {
  String _selectedPlanId = _momentsPlans[2].id;

  MomentsPlanOption get _selectedPlan => _momentsPlans.firstWhere(
        (plan) => plan.id == _selectedPlanId,
        orElse: () => _momentsPlans[2],
      );

  void _onBuy() {
    AppToast.showInfo(context, 'Coming soon');
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider.select((s) => s.user?.role));
    if (AppNavDestinations.isCreatorOrAdmin(role)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/account');
      });
      return const SizedBox.shrink();
    }

    final user = ref.watch(authProvider.select((s) => s.user));
    final billing = ref.watch(callBillingProvider);
    final coins = shouldShowLiveUserCoins(isCreator: false, billing: billing)
        ? billing.userCoins
        : (user?.coins ?? 0);
    final scheme = Theme.of(context).colorScheme;

    return MainLayout(
      selectedIndex: appNavSelectedIndex(ref, '/account'),
      accountMenuStyle: true,
      appBar: buildAccountFlowAppBar(
        context,
        title: 'Moments Plan',
        actions: [BrandHeaderCoinsChip(coins: coins)],
      ),
      child: ColoredBox(
        color: AppBrandGradients.accountMenuPageBackground,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                children: [
                  _HeroBanner(scheme: scheme),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Choose your plan',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final plan in _momentsPlans) ...[
                    _MomentsPlanCard(
                      plan: plan,
                      selected: plan.id == _selectedPlanId,
                      onTap: () => setState(() => _selectedPlanId = plan.id),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
            _BuyFooter(
              priceInr: _selectedPlan.priceInr,
              label: _selectedPlan.label,
              onBuy: _onBuy,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surfaceContainerHigh,
            scheme.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppBrandGradients.accountMenuCardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unlock paid Moments',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Get access to premium creator moments for the duration of your plan.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.play_circle_outline,
            size: 52,
            color: AppBrandGradients.accountMenuIconTint.withValues(alpha: 0.85),
          ),
        ],
      ),
    );
  }
}

class _MomentsPlanCard extends StatelessWidget {
  const _MomentsPlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final MomentsPlanOption plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppBrandGradients.accountMenuIconTint
                  : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            boxShadow: AppBrandGradients.accountMenuCardShadow,
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (plan.badge != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppBrandGradients.accountMenuIconTint
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          plan.badge!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppBrandGradients.accountMenuIconTint,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      plan.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${plan.durationDays} days access',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${plan.priceInr}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppBrandGradients.accountMenuIconTint,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected
                    ? AppBrandGradients.accountMenuIconTint
                    : scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuyFooter extends StatelessWidget {
  const _BuyFooter({
    required this.priceInr,
    required this.label,
    required this.onBuy,
  });

  final int priceInr;
  final String label;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '₹$priceInr',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: onBuy,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(140, 48),
                    backgroundColor: AppBrandGradients.accountMenuIconTint,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Buy',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
