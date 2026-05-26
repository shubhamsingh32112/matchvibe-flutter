import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/decorative_asset_image.dart';
import '../constants/transaction_assets.dart';

class TransactionsBalanceCard extends StatelessWidget {
  final int coins;
  final double? inrEstimate;
  final int todayNet;
  final VoidCallback? onScrollToHistory;

  const TransactionsBalanceCard({
    super.key,
    required this.coins,
    required this.todayNet,
    this.inrEstimate,
    this.onScrollToHistory,
  });

  @override
  Widget build(BuildContext context) {
    final todayPrefix = todayNet >= 0 ? '+' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppBrandGradients.accountMenuHeaderGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppBrandGradients.accountMenuCardShadow,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 148, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Available Balance',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppBrandGradients.walletCoinGold,
                        ),
                        child: const Icon(
                          Icons.monetization_on,
                          color: AppBrandGradients.walletOnGold,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '$coins Coins',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (inrEstimate != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '₹${inrEstimate!.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Available Balance',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: 'Buy Coins',
                          icon: Icons.shopping_cart_outlined,
                          background: Colors.white,
                          foreground: AppBrandGradients.accountMenuIconTint,
                          onTap: () => context.push('/wallet'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionButton(
                          label: 'History',
                          icon: Icons.history,
                          background: Colors.white.withValues(alpha: 0.18),
                          foreground: Colors.white,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          onTap: onScrollToHistory,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 16,
              right: 108,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$todayPrefix$todayNet',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFFD54F),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  Text(
                    'Today',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              right: -8,
              top: 12,
              child: _HeroIllustration(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: DecorativeAssetImage(
        assetPath: TransactionAssets.walletHero,
        width: 140,
        height: 140,
        fallbackIcon: Icons.account_balance_wallet,
        fallbackIconSize: 72,
        fallbackIconColor: Colors.white.withValues(alpha: 0.35),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Border? border;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: border,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simplified earnings hero for creators (no buy-coins CTAs).
class TransactionsCreatorBalanceCard extends StatelessWidget {
  final int totalEarned;

  const TransactionsCreatorBalanceCard({
    super.key,
    required this.totalEarned,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppBrandGradients.accountMenuHeaderGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppBrandGradients.accountMenuCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Earnings',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$totalEarned',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'From loaded transactions',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
