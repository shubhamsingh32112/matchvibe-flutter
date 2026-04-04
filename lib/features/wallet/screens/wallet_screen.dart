import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/providers/auth_provider.dart';
import '../../creator/providers/creator_dashboard_provider.dart';
import '../../home/providers/availability_provider.dart';
import '../providers/wallet_pricing_provider.dart';
import '../services/payment_service.dart';
import '../models/earnings_model.dart';
import '../models/wallet_pricing_model.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../../shared/widgets/gem_icon.dart';
import '../../../shared/styles/app_brand_styles.dart';

/// Bottom sheet wrapper for wallet screen
class WalletBottomSheet extends StatelessWidget {
  const WalletBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => const WalletScreen(),
    );
  }
}

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final PaymentService _paymentService = PaymentService();
  bool _isAddingCoins = false;

  @override
  void initState() {
    super.initState();

    // Refresh user data to ensure balance is up-to-date when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUserData();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Refresh user data from backend to get latest coin balance
  Future<void> _refreshUserData() async {
    try {
      debugPrint('🔄 [WALLET] Refreshing user data to update balance...');
      await ref.read(authProvider.notifier).refreshUser();
      debugPrint('✅ [WALLET] User data refreshed');
    } catch (e) {
      debugPrint('⚠️  [WALLET] Failed to refresh user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final coins = user?.coins ?? 0;
    final isCreator = user?.role == 'creator' || user?.role == 'admin';
    final walletPricingAsync = isCreator
        ? null
        : ref.watch(walletPricingProvider);

    // Watch the dashboard provider for creator earnings (auto-refreshes via socket)
    final earningsAsync = isCreator
        ? ref.watch(dashboardEarningsProvider)
        : null;
    ref.watch(socketServiceProvider);

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
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
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
                      'Wallet',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _CoinsPill(coins: coins),
                ],
              ),
            ),
            // Content
            Expanded(
              child: isCreator
                  ? earningsAsync!.when(
                      data: (earnings) => _CreatorWalletView(
                        earnings: earnings,
                        isLoadingEarnings: false,
                        earningsError: null,
                        onRefresh: () async {
                          await _refreshUserData();
                          ref.invalidate(creatorDashboardProvider);
                        },
                        onRetry: () => ref.invalidate(creatorDashboardProvider),
                        buildCallEarningCard: _buildCallEarningCard,
                      ),
                      loading: () => const Center(child: LoadingIndicator()),
                      error: (error, _) => ErrorState(
                        title: 'Failed to load earnings',
                        message: UserMessageMapper.userMessageFor(
                          error,
                          fallback: 'Couldn\'t load earnings. Please try again.',
                        ),
                        actionLabel: 'Retry',
                        onAction: () => ref.invalidate(creatorDashboardProvider),
                      ),
                    )
                  : walletPricingAsync!.when(
                      data: (pricingData) => _UserWalletView(
                        isAddingCoins: _isAddingCoins,
                        packages: pricingData.packages,
                        onRefresh: () async {
                          await _refreshUserData();
                          ref.invalidate(walletPricingProvider);
                        },
                        onRetry: () => ref.invalidate(walletPricingProvider),
                        onAddCoins: _addCoins,
                      ),
                      loading: () => const Center(child: LoadingIndicator()),
                      error: (error, _) => ErrorState(
                        title: 'Failed to load wallet pricing',
                        message: UserMessageMapper.userMessageFor(
                          error,
                          fallback: 'Couldn\'t load coin packs. Please try again.',
                        ),
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

  Widget _buildCallEarningCard(CallEarning call) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.videocam,
              color: scheme.onPrimaryContainer,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  call.callerUsername,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      call.durationFormatted,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GemIcon(
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '+${call.earnings.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  'coins',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Start web checkout flow for selected pack.
  Future<void> _addCoins(int coins) async {
    if (_isAddingCoins) return; // Prevent multiple simultaneous requests

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
        AppToast.showInfo(
          context,
          'Complete payment on the website. App will reopen automatically.',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && loadingDialogVisible) {
        Navigator.of(context).pop();
        loadingDialogVisible = false;
      }

      // Show error message
      if (mounted) {
        AppToast.showError(
          context,
          UserMessageMapper.userMessageFor(
            e,
            fallback: 'Couldn\'t start checkout. Please try again.',
          ),
          duration: const Duration(seconds: 3),
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
}

class _CreatorWalletView extends StatelessWidget {
  final CreatorEarnings? earnings;
  final bool isLoadingEarnings;
  final String? earningsError;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final Widget Function(CallEarning call) buildCallEarningCard;

  const _CreatorWalletView({
    required this.earnings,
    required this.isLoadingEarnings,
    required this.earningsError,
    required this.onRefresh,
    required this.onRetry,
    required this.buildCallEarningCard,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (isLoadingEarnings) {
      return const Center(child: LoadingIndicator());
    }

    if (earningsError != null) {
      return ErrorState(
        title: 'Failed to load earnings',
        message: earningsError!,
        actionLabel: 'Retry',
        onAction: onRetry,
      );
    }

    if (earnings == null) {
      return const EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No earnings data',
        message:
            'Your earnings will appear here once you start receiving calls',
      );
    }

    final e = earnings!;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: scheme.onSurface,
      backgroundColor: AppBrandGradients.walletRefreshIndicatorBackground,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total Earnings Card
              AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          size: 20,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Total Earnings',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        GemIcon(
                          size: 36,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            e.totalEarnings.toStringAsFixed(0),
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'coins',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _CreatorStatItem(
                            label: 'Total Calls',
                            value: e.totalCalls.toString(),
                            icon: Icons.phone,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _CreatorStatItem(
                            label: 'Total Minutes',
                            value: e.totalMinutes.toStringAsFixed(1),
                            icon: Icons.timer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/creator/tasks'),
                        icon: const Icon(Icons.task_alt),
                        label: const Text('View Tasks & Rewards'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Earnings per minute info - Current rate
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: scheme.onSurfaceVariant,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Current rate: ${e.earningsPerMinute.toStringAsFixed(2)} coins/min (${e.calculatedPercentage}% of call rate)',
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (e.avgEarningsPerMinute != null &&
                        e.avgEarningsPerMinute! != e.earningsPerMinute) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 32),
                        child: Text(
                          'Historical average: ${e.avgEarningsPerMinute!.toStringAsFixed(2)} coins/min',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Call History
              Text(
                'Call History',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (e.calls.isEmpty)
                const EmptyState(
                  icon: Icons.phone_disabled_outlined,
                  title: 'No calls yet',
                  message: 'Your call history will appear here',
                )
              else
                ...e.calls.map((call) => buildCallEarningCard(call)),
            ],
          ),
        ),
      );
  }
}

class _CreatorStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _CreatorStatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: scheme.onPrimaryContainer, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserWalletView extends StatelessWidget {
  final bool isAddingCoins;
  final List<WalletCoinPack> packages;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final void Function(int coins) onAddCoins;

  const _UserWalletView({
    required this.isAddingCoins,
    required this.packages,
    required this.onRefresh,
    required this.onRetry,
    required this.onAddCoins,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uiPackages = packages
        .asMap()
        .entries
        .map(
          (entry) => _CoinPack(
            coins: entry.value.coins,
            price: entry.value.priceInr,
            oldPrice: entry.value.oldPriceInr,
            badge: entry.value.badge,
          ),
        )
        .toList();

    if (uiPackages.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'No coin packs available',
          message: 'Please try again shortly',
          actionLabel: 'Retry',
          onAction: onRetry,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: scheme.onSurface,
      backgroundColor: AppBrandGradients.walletRefreshIndicatorBackground,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose your coin pack',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Secure payment and instant balance update',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isAddingCoins)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: uiPackages.length,
              itemBuilder: (context, index) {
                final pack = uiPackages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _VerticalCoinPackCard(
                    pack: pack,
                    onTap: isAddingCoins ? null : () => onAddCoins(pack.coins),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _CoinsPill extends StatelessWidget {
  final int coins;
  const _CoinsPill({required this.coins});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.scrim.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GemIcon(
                size: 20,
                color: scheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                coins.toString(),
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
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

class _VerticalCoinPackCard extends StatelessWidget {
  final _CoinPack pack;
  final VoidCallback? onTap;

  const _VerticalCoinPackCard({required this.pack, this.onTap});

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
              // Coin Icon on the left
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
