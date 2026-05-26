import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/gem_icon.dart';

class HelpTransactionSummaryCard extends StatelessWidget {
  final int credits;
  final int debits;
  final int balance;
  final VoidCallback onTap;

  const HelpTransactionSummaryCard({
    super.key,
    required this.credits,
    required this.debits,
    required this.balance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppBrandGradients.accountMenuCardShadow,
              color: Colors.white,
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE7F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: AppBrandGradients.accountMenuIconTint,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Transaction Summary',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A1A1A),
                                ),
                      ),
                    ),
                    _CircleChevron(onTap: onTap),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _StatColumn(
                        icon: Icons.add,
                        iconColor: const Color(0xFF43A047),
                        label: 'Credits',
                        value: '$credits',
                      ),
                    ),
                    _VerticalDivider(),
                    Expanded(
                      child: _StatColumn(
                        icon: Icons.remove,
                        iconColor: const Color(0xFFE53935),
                        label: 'Debits',
                        value: '$debits',
                      ),
                    ),
                    _VerticalDivider(),
                    Expanded(
                      child: _StatColumn(
                        icon: Icons.account_balance_outlined,
                        iconColor: AppBrandGradients.accountMenuIconTint,
                        label: 'Balance',
                        value: '$balance',
                        showGem: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleChevron extends StatelessWidget {
  final VoidCallback onTap;

  const _CircleChevron({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F0F7),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(
            Icons.chevron_right,
            size: 22,
            color: Color(0xFF6B6B6B),
          ),
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: const Color(0xFFE0E0E0),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool showGem;

  const _StatColumn({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.showGem = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B6B6B),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showGem) ...[
              const GemIcon(size: 16),
              const SizedBox(width: 2),
            ],
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppBrandGradients.accountMenuIconTint,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
