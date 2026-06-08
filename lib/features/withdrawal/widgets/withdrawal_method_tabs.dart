import 'package:flutter/material.dart';

import '../theme/withdrawal_tokens.dart';

class WithdrawalMethodTabs extends StatelessWidget {
  const WithdrawalMethodTabs({
    super.key,
    required this.useUpi,
    required this.onUseUpiChanged,
  });

  final bool useUpi;
  final ValueChanged<bool> onUseUpiChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MethodTab(
            label: 'UPI',
            icon: Icons.account_balance,
            selected: useUpi,
            onTap: () => onUseUpiChanged(true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MethodTab(
            label: 'Bank Account',
            icon: Icons.account_balance_outlined,
            selected: !useUpi,
            onTap: () => onUseUpiChanged(false),
          ),
        ),
      ],
    );
  }
}

class _MethodTab extends StatelessWidget {
  const _MethodTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? WithdrawalTokens.primaryPurple : WithdrawalTokens.borderGrey;
    final fillColor = selected
        ? WithdrawalTokens.primaryPurple.withValues(alpha: 0.08)
        : Colors.white;
    final contentColor =
        selected ? WithdrawalTokens.primaryPurple : WithdrawalTokens.labelGrey;

    return Material(
      color: fillColor,
      borderRadius: BorderRadius.circular(WithdrawalTokens.fieldRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WithdrawalTokens.fieldRadius),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(WithdrawalTokens.fieldRadius),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: contentColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: contentColor,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
