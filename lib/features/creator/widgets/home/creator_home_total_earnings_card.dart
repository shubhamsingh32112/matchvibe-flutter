import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/gem_icon.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../providers/creator_dashboard_provider.dart';
import '../../theme/creator_home_tokens.dart';
import '../../utils/creator_earnings_display.dart';

class CreatorHomeTotalEarningsCard extends ConsumerWidget {
  const CreatorHomeTotalEarningsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(creatorDashboardProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: CreatorHomeTokens.sectionSpacing),
      child: dashboardAsync.when(
        data: (dashboard) {
          final coins = dashboard.earnings.totalEarnings;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: CreatorHomeTokens.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Total Earnings',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: CreatorHomeTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: CreatorHomeTokens.labelGrey.withValues(alpha: 0.9),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: CreatorHomeTokens.primaryPurple.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '1 Coin = ₹0.65',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: CreatorHomeTokens.primaryPurple,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const GemIcon(size: 28),
                    const SizedBox(width: 8),
                    Text(
                      CreatorEarningsDisplay.formatCoins(coins),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: CreatorHomeTokens.textPrimary,
                        height: 1,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 40,
                      color: CreatorHomeTokens.primaryPurple.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  CreatorEarningsDisplay.formatInr(coins),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CreatorHomeTokens.completedGreen,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: CreatorHomeTokens.withdrawalGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push('/creator/withdraw'),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Withdraw',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 18,
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
          height: 160,
          decoration: CreatorHomeTokens.cardDecoration(),
          child: const Center(child: LoadingIndicator()),
        ),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}
