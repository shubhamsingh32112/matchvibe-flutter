import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants/creator_stat_assets.dart';
import '../../../moments/providers/moments_providers.dart';
import '../../../wallet/constants/transaction_assets.dart';
import '../../../../core/config/app_config_provider.dart';
import '../../../../core/utils/compact_count_formatter.dart';
import '../../../wallet/providers/wallet_pricing_provider.dart';
import '../../../wallet/utils/transaction_ui_mapper.dart';
import '../../../withdrawal/providers/withdrawal_provider.dart';
import '../../providers/creator_dashboard_provider.dart';
import '../../theme/creator_home_tokens.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import 'creator_home_stat_column.dart';

class CreatorHomeStatsTile extends ConsumerStatefulWidget {
  const CreatorHomeStatsTile({super.key});

  @override
  ConsumerState<CreatorHomeStatsTile> createState() =>
      _CreatorHomeStatsTileState();
}

class _CreatorHomeStatsTileState extends ConsumerState<CreatorHomeStatsTile> {
  bool _loadedWithdrawals = false;

  @override
  void initState() {
    super.initState();
    _loadWithdrawals();
  }

  Future<void> _loadWithdrawals() async {
    if (_loadedWithdrawals) return;
    await ref.read(withdrawalProvider.notifier).loadWithdrawals();
    _loadedWithdrawals = true;
  }

  bool get _hasPendingWithdrawal {
    final withdrawals = ref.watch(withdrawalProvider).withdrawals;
    return withdrawals.any((w) => w.status == 'pending');
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(creatorDashboardProvider);
    final pricingAsync = ref.watch(walletPricingProvider);
    final momentsEnabled = ref.watch(appFeaturesProvider).momentsEnabled;
    final creatorId = dashboardAsync.valueOrNull?.creatorProfile.id;
    final summaryAsync = creatorId != null && momentsEnabled
        ? ref.watch(creatorSummaryProvider(creatorId))
        : null;

    return dashboardAsync.when(
      data: (dashboard) {
        final earnings = dashboard.earnings;
        final packs = pricingAsync.valueOrNull?.packages ?? [];
        final inr = TransactionUiMapper.estimateInrValue(
          earnings.totalEarnings.round(),
          packs,
        );
        final earningsLabel = inr != null
            ? '₹ ${inr.toStringAsFixed(0).replaceAllMapped(
                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                (m) => '${m[1]},',
              )}'
            : '${earnings.totalEarnings.toStringAsFixed(0)} coins';

        return Container(
          margin: const EdgeInsets.only(bottom: CreatorHomeTokens.sectionSpacing),
          padding: const EdgeInsets.all(16),
          decoration: CreatorHomeTokens.cardDecoration(),
          child: Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Center(
                        child: CreatorHomeStatColumn(
                          iconAssetPath: TransactionAssets.walletHero,
                          iconSize: 50,
                          value: earningsLabel,
                        ),
                      ),
                    ),
                    const CreatorHomeStatDivider(),
                    Expanded(
                      child: Center(
                        child: CreatorHomeStatColumn(
                          iconAssetPath: CreatorStatAssets.calls,
                          iconSize: 50,
                          value: '${earnings.totalCalls}',
                        ),
                      ),
                    ),
                    const CreatorHomeStatDivider(),
                    Expanded(
                      child: Center(
                        child: CreatorHomeStatColumn(
                          iconAssetPath: CreatorStatAssets.callMinutes,
                          iconSize: 50,
                          value: earnings.totalMinutes.toStringAsFixed(0),
                          unitSuffix: 'min',
                        ),
                      ),
                    ),
                    const CreatorHomeStatDivider(),
                    Expanded(
                      child: Center(
                        child: CreatorHomeStatColumn(
                          iconAssetPath: CreatorStatAssets.onlineMinutes,
                          iconSize: 50,
                          value: '${dashboard.onlineTodaySeconds ~/ 60}',
                          unitSuffix: 'min',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (momentsEnabled && summaryAsync != null) ...[
                const SizedBox(height: 12),
                summaryAsync.when(
                  data: (summary) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 20,
                        color: CreatorHomeTokens.textPrimary.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${formatCompactCount(summary.followerCount)} Followers',
                        style: const TextStyle(
                          color: CreatorHomeTokens.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  loading: () => const Text(
                    'Followers —',
                    style: TextStyle(
                      color: CreatorHomeTokens.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  error: (_, __) => const Text(
                    'Followers —',
                    style: TextStyle(
                      color: CreatorHomeTokens.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _hasPendingWithdrawal
                        ? null
                        : CreatorHomeTokens.withdrawalGradient,
                    color: _hasPendingWithdrawal
                        ? CreatorHomeTokens.labelGrey
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _hasPendingWithdrawal
                          ? null
                          : () => context.push('/creator/withdraw'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.account_balance_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _hasPendingWithdrawal
                                  ? 'Withdrawal Pending'
                                  : 'Withdrawal',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        height: 180,
        margin: const EdgeInsets.only(bottom: CreatorHomeTokens.sectionSpacing),
        decoration: CreatorHomeTokens.cardDecoration(),
        child: const Center(child: LoadingIndicator()),
      ),
      error: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: CreatorHomeTokens.sectionSpacing),
        padding: const EdgeInsets.all(16),
        decoration: CreatorHomeTokens.cardDecoration(),
        child: Column(
          children: [
            const Text(
              'Could not load stats',
              style: TextStyle(color: CreatorHomeTokens.textPrimary),
            ),
            TextButton(
              onPressed: () => ref.invalidate(creatorDashboardProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
