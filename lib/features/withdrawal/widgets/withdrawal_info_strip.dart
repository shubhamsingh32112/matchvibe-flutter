import 'package:flutter/material.dart';

import '../../../shared/widgets/gem_icon.dart';
import '../constants/withdrawal_assets.dart';
import '../theme/withdrawal_tokens.dart';

class WithdrawalInfoStrip extends StatelessWidget {
  const WithdrawalInfoStrip({super.key});

  static const double _iconSize = 28;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: WithdrawalTokens.infoStripBg,
        borderRadius: BorderRadius.circular(WithdrawalTokens.fieldRadius),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _InfoColumn(
                icon: const GemIcon(size: _iconSize),
                label: 'Min. Withdrawal',
                value: '100 coins',
              ),
            ),
            Container(width: 1, color: WithdrawalTokens.borderGrey),
            Expanded(
              child: _InfoColumn(
                icon: _StripIcon(assetPath: WithdrawalAssets.secureSafe),
                label: 'Secure',
                value: '& Safe',
              ),
            ),
            Container(width: 1, color: WithdrawalTokens.borderGrey),
            Expanded(
              child: _InfoColumn(
                icon: _StripIcon(assetPath: WithdrawalAssets.instantProcessing),
                label: 'Instant',
                value: 'Processing',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StripIcon extends StatelessWidget {
  const _StripIcon({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: WithdrawalInfoStrip._iconSize,
      height: WithdrawalInfoStrip._iconSize,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({
    required this.icon,
    required this.label,
    required this.value,
  });

  final Widget icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: WithdrawalTokens.labelGrey,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: WithdrawalTokens.valueDark,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
