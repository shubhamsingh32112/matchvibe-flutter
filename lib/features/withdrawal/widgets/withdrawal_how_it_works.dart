import 'package:flutter/material.dart';

import '../theme/withdrawal_tokens.dart';

class WithdrawalHowItWorks extends StatelessWidget {
  const WithdrawalHowItWorks({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WithdrawalTokens.bannerLavender,
        borderRadius: BorderRadius.circular(WithdrawalTokens.fieldRadius),
        border: Border.all(color: WithdrawalTokens.borderGrey.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: WithdrawalTokens.primaryPurple.withValues(alpha: 0.85),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'How withdrawals work',
                style: TextStyle(
                  color: WithdrawalTokens.valueDark,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _InfoRow(text: 'Minimum withdrawal: 100 coins'),
          const SizedBox(height: 8),
          const _InfoRow(text: 'Submit your request — coins stay in your wallet'),
          const SizedBox(height: 8),
          const _InfoRow(text: 'Admin reviews & approves, then marks paid (coins deducted)'),
          const SizedBox(height: 8),
          const _InfoRow(text: 'Payment processed & marked as paid'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(
            color: WithdrawalTokens.primaryPurple,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: WithdrawalTokens.labelGrey,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
