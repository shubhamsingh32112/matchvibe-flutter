import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_spacing.dart';
import '../utils/transaction_ui_mapper.dart';

class TransactionsOverviewRow extends StatelessWidget {
  final TransactionOverviewStats stats;

  const TransactionsOverviewRow({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D2D2D),
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _OverviewCard(
                  label: 'Total Purchased',
                  value: '${stats.totalPurchased} Coins',
                  icon: Icons.shopping_bag_outlined,
                  background: const Color(0xFFE8F5E9),
                  accent: TransactionUiMapper.creditGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewCard(
                  label: 'Total Spent',
                  value: '${stats.totalSpent} Coins',
                  icon: Icons.arrow_downward_rounded,
                  background: const Color(0xFFFFEBEE),
                  accent: TransactionUiMapper.debitRed,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewCard(
                  label: 'Referral Earnings',
                  value: '${stats.referralEarnings} Coins',
                  icon: Icons.people_outline,
                  background: const Color(0xFFF3E5F5),
                  accent: TransactionUiMapper.referralPurple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color background;
  final Color accent;

  const _OverviewCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.background,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent.withValues(alpha: 0.85),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
