import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/vip_page_tokens.dart';
import 'vip_badge.dart';

class VipActiveMemberPanel extends StatelessWidget {
  const VipActiveMemberPanel({
    super.key,
    required this.expiresLabel,
    required this.remaining,
    required this.total,
  });

  final String expiresLabel;
  final int remaining;
  final int total;

  @override
  Widget build(BuildContext context) {
    final used = (total - remaining).clamp(0, total);
    final progress = total > 0 ? used / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VipPageTokens.horizontalPadding,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: VipPageTokens.cardGradient,
          borderRadius: BorderRadius.circular(VipPageTokens.cardRadius),
          border: Border.all(
            color: VipPageTokens.borderGold.withValues(alpha: 0.45),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: VipBadge()),
            const SizedBox(height: 10),
            Text(
              expiresLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: VipPageTokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Free moments today: $remaining of $total left',
              style: const TextStyle(
                color: VipPageTokens.textMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                color: VipPageTokens.borderGold,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => context.push('/vip/scheduled'),
              style: OutlinedButton.styleFrom(
                foregroundColor: VipPageTokens.textGold,
                side: BorderSide(
                  color: VipPageTokens.borderGold.withValues(alpha: 0.6),
                ),
              ),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('View scheduled calls'),
            ),
          ],
        ),
      ),
    );
  }
}
