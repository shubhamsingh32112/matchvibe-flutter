import 'package:flutter/material.dart';

import '../../wallet/constants/transaction_assets.dart';
import '../theme/withdrawal_tokens.dart';
import '../../../shared/widgets/decorative_asset_image.dart';

class WithdrawalBalanceCard extends StatelessWidget {
  const WithdrawalBalanceCard({super.key, required this.coins});

  final int coins;

  static const int _minWithdrawal = 100;

  @override
  Widget build(BuildContext context) {
    final chipText = coins < _minWithdrawal
        ? 'Reach 100 coins to withdraw'
        : 'Keep going! You can do more.';

    return Container(
      decoration: WithdrawalTokens.cardDecoration(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 120, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Available Balance',
                  style: TextStyle(
                    color: WithdrawalTokens.labelGrey,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$coins',
                      style: const TextStyle(
                        color: WithdrawalTokens.primaryPurple,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'coins',
                      style: TextStyle(
                        color: WithdrawalTokens.primaryPurple,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: WithdrawalTokens.bannerLavender,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 16,
                        color: WithdrawalTokens.primaryPurple.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          chipText,
                          style: TextStyle(
                            color: WithdrawalTokens.primaryPurple.withValues(alpha: 0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            right: -4,
            top: 8,
            child: DecorativeAssetImage(
              assetPath: TransactionAssets.walletHero,
              width: 110,
              height: 110,
              fallbackIcon: Icons.account_balance_wallet,
              fallbackIconSize: 48,
              fallbackIconColor: WithdrawalTokens.primaryPurple,
            ),
          ),
        ],
      ),
    );
  }
}
