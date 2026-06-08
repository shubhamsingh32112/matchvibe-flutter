import 'package:flutter/material.dart';

import '../models/withdrawal_model.dart';
import '../theme/withdrawal_tokens.dart';

class WithdrawalHistoryCard extends StatelessWidget {
  const WithdrawalHistoryCard({super.key, required this.withdrawal});

  final WithdrawalRequest withdrawal;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(withdrawal.status);
    final statusIcon = _statusIcon(withdrawal.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: WithdrawalTokens.cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon, color: statusColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${withdrawal.amount.toInt()} coins',
                  style: const TextStyle(
                    color: WithdrawalTokens.valueDark,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(withdrawal.requestedAt),
                  style: const TextStyle(
                    color: WithdrawalTokens.labelGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              withdrawal.statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.amber.shade800;
      case 'approved':
        return WithdrawalTokens.instantBlue;
      case 'rejected':
        return Colors.red.shade700;
      case 'paid':
        return WithdrawalTokens.secureGreen;
      default:
        return WithdrawalTokens.labelGrey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_top;
      case 'approved':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'paid':
        return Icons.paid_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}, '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
