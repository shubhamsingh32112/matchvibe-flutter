import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/gem_icon.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../providers/creator_dashboard_provider.dart';
import '../../theme/creator_home_tokens.dart';
import '../../utils/creator_earnings_display.dart';

class CreatorHomeCallEarningsRow extends ConsumerWidget {
  const CreatorHomeCallEarningsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(creatorDashboardProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: CreatorHomeTokens.sectionSpacing),
      child: dashboardAsync.when(
        data: (dashboard) {
          final free = dashboard.earnings.freeCallEarnings;
          final paid = dashboard.earnings.paidCallEarnings;
          final total = free + paid;
          final freePct = total > 0 ? (free / total) : 0.0;
          final paidPct = total > 0 ? (paid / total) : 0.0;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CallEarningsCard(
                  title: 'Free Call Earnings',
                  icon: Icons.phone_in_talk_rounded,
                  iconColor: CreatorHomeTokens.completedGreen,
                  coins: free,
                  percentOfTotal: freePct,
                  barColor: CreatorHomeTokens.completedGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CallEarningsCard(
                  title: 'Paid Call Earnings',
                  icon: Icons.phone_rounded,
                  iconColor: CreatorHomeTokens.pinkAccent,
                  coins: paid,
                  percentOfTotal: paidPct,
                  barColor: CreatorHomeTokens.pinkAccent,
                ),
              ),
            ],
          );
        },
        loading: () => Container(
          height: 140,
          decoration: CreatorHomeTokens.cardDecoration(),
          child: const Center(child: LoadingIndicator()),
        ),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}

class _CallEarningsCard extends StatelessWidget {
  const _CallEarningsCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.coins,
    required this.percentOfTotal,
    required this.barColor,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final double coins;
  final double percentOfTotal;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final pctLabel = '${(percentOfTotal * 100).round()}% of Total';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: CreatorHomeTokens.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: CreatorHomeTokens.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.info_outline,
                size: 14,
                color: CreatorHomeTokens.labelGrey.withValues(alpha: 0.9),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const GemIcon(size: 16),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  CreatorEarningsDisplay.formatCoins(coins),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: CreatorHomeTokens.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            CreatorEarningsDisplay.formatInr(coins),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: CreatorHomeTokens.labelGrey,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentOfTotal.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: CreatorHomeTokens.bannerLavender,
              color: barColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pctLabel,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: CreatorHomeTokens.labelGrey,
            ),
          ),
        ],
      ),
    );
  }
}
