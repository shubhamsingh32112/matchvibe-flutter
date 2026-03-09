import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/wallet/providers/wallet_pricing_provider.dart';
import '../../features/wallet/services/payment_service.dart';
import '../styles/app_brand_styles.dart';
import '../widgets/ui_primitives.dart';
import '../widgets/gem_icon.dart';
import '../widgets/loading_indicator.dart';

/// Bottom sheet wrapper for coin purchase popup
class CoinPurchaseBottomSheet extends StatelessWidget {
  const CoinPurchaseBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => const CoinPurchasePopup(),
    );
  }
}

/// Bottom sheet-style pop-up for purchasing coins.
/// 
/// Shows coin packs in horizontal tiles similar to wallet screen.
/// Uses the same gem icon and styling as wallet.
class CoinPurchasePopup extends ConsumerStatefulWidget {
  const CoinPurchasePopup({super.key});

  @override
  ConsumerState<CoinPurchasePopup> createState() => _CoinPurchasePopupState();
}

class _CoinPurchasePopupState extends ConsumerState<CoinPurchasePopup> {
  final PaymentService _paymentService = PaymentService();
  bool _isAddingCoins = false;

  /// Start web checkout flow for selected pack.
  Future<void> _addCoins(int coins) async {
    if (_isAddingCoins) return;

    bool loadingDialogVisible = false;
    setState(() {
      _isAddingCoins = true;
    });

    try {
      // Show loading dialog while creating order
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      loadingDialogVisible = true;

      // Step 1: Initiate web checkout session
      final checkoutData = await _paymentService.initiateWebCheckout(coins);
      final checkoutUrl = checkoutData['checkoutUrl'] as String;

      // Close loading dialog
      if (mounted && loadingDialogVisible) {
        Navigator.of(context).pop();
        loadingDialogVisible = false;
      }

      // Step 2: Open website checkout in external browser
      final uri = Uri.parse(checkoutUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('Unable to open checkout website');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Complete payment on the website. App will reopen automatically.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
        // Close the pop-up after opening checkout
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && loadingDialogVisible) {
        Navigator.of(context).pop();
        loadingDialogVisible = false;
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to start checkout: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingCoins = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletPricingAsync = ref.watch(walletPricingProvider);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: AppBrandGradients.appBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Buy Coins',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: walletPricingAsync.when(
                data: (pricingData) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(walletPricingProvider);
                  },
                  color: scheme.onSurface,
                  backgroundColor: AppBrandGradients.walletRefreshIndicatorBackground,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                          child: Text(
                            'Choose your coin pack',
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: pricingData.packages.length,
                          itemBuilder: (context, index) {
                            final pack = pricingData.packages[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _CoinPackCard(
                                pack: _CoinPack(
                                  coins: pack.coins,
                                  price: pack.priceInr,
                                  oldPrice: pack.oldPriceInr,
                                  badge: pack.badge,
                                ),
                                onTap: _isAddingCoins ? null : () => _addCoins(pack.coins),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                loading: () => const Center(child: LoadingIndicator()),
                error: (error, _) => ErrorState(
                  title: 'Failed to load coin packs',
                  message: error.toString(),
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(walletPricingProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _CoinPack {
  final int coins;
  final int price;
  final int? oldPrice;
  final String? badge;

  const _CoinPack({
    required this.coins,
    required this.price,
    this.oldPrice,
    this.badge,
  });
}

class _CoinPackCard extends StatelessWidget {
  final _CoinPack pack;
  final VoidCallback? onTap;

  const _CoinPackCard({required this.pack, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasDiscount = pack.oldPrice != null && pack.oldPrice! > pack.price;
    final discountPercent = hasDiscount
        ? (((pack.oldPrice! - pack.price) / pack.oldPrice!) * 100).round()
        : null;

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      margin: EdgeInsets.zero,
      child: Stack(
        children: [
          Row(
            children: [
              // Gem Icon on the left
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: GemIcon(
                  size: 24,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              // Coins amount in the middle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${pack.coins} coins',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (pack.badge != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        pack.badge!,
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Price on the right
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pack.oldPrice != null)
                    Text(
                      '₹${pack.oldPrice}',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        decoration: TextDecoration.lineThrough,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  if (pack.oldPrice != null) const SizedBox(height: 2),
                  Text(
                    '₹${pack.price}',
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Discount badge at top right (if applicable)
          if (hasDiscount && discountPercent != null)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '-$discountPercent%',
                  style: TextStyle(
                    color: scheme.onTertiaryContainer,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
