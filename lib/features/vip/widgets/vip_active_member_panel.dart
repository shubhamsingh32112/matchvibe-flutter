import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/vip_page_tokens.dart';
import 'vip_badge.dart';

class VipActiveMemberPanel extends StatelessWidget {
  const VipActiveMemberPanel({
    super.key,
    required this.expiresLabel,
  });

  final String expiresLabel;

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 8),
            const Text(
              'Unlimited Moments · Unlimited chats · Priority perks',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: VipPageTokens.textMuted,
                fontSize: 13,
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
