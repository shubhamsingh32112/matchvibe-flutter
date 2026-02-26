import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/providers/auth_provider.dart';
import '../../creator/providers/creator_dashboard_provider.dart';
import '../../home/providers/availability_provider.dart';
import '../providers/wallet_pricing_provider.dart';
import '../services/payment_service.dart';
import '../services/coin_image_service.dart';
import '../models/earnings_model.dart';
import '../models/wallet_pricing_model.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../../shared/styles/app_brand_styles.dart';

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

    return AppScaffold(
      padded: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Wallet',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _CoinsPill(coins: coins),
              ],
            ),
          ),
          if (isCreator)
            earningsAsync!.when(
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
              loading: () => _CreatorWalletView(
                earnings: null,
                isLoadingEarnings: true,
                earningsError: null,
                onRefresh: () async {},
                onRetry: () {},
                buildCallEarningCard: _buildCallEarningCard,
              ),
              error: (error, _) => _CreatorWalletView(
                earnings: null,
                isLoadingEarnings: false,
                earningsError: error.toString(),
                onRefresh: () async {
                  ref.invalidate(creatorDashboardProvider);
                },
                onRetry: () => ref.invalidate(creatorDashboardProvider),
                buildCallEarningCard: _buildCallEarningCard,
              ),
            )
          else
            walletPricingAsync!.when(
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
              loading: () =>
                  const Expanded(child: Center(child: LoadingIndicator())),
              error: (error, _) => Expanded(
                child: ErrorState(
                  title: 'Failed to load wallet pricing',
                  message: error.toString(),
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(walletPricingProvider),
                ),
              ),
            ),
        ],
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
              gradient: AppBrandGradients.walletCoinGold,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.videocam, color: scheme.onSurface),
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
                Text(
                  '${call.durationFormatted} • ${call.earnings.toStringAsFixed(0)} coins',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${call.earnings.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppBrandGradients.walletEarningsHighlight,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'coins',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Complete payment on the website. App will reopen automatically.',
            ),
            duration: Duration(seconds: 3),
          ),
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
      return const Expanded(child: Center(child: LoadingIndicator()));
    }

    if (earningsError != null) {
      return Expanded(
        child: ErrorState(
          title: 'Failed to load earnings',
          message: earningsError!,
          actionLabel: 'Retry',
          onAction: onRetry,
        ),
      );
    }

    if (earnings == null) {
      return const Expanded(
        child: EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'No earnings data',
          message:
              'Your earnings will appear here once you start receiving calls',
        ),
      );
    }

    final e = earnings!;

    return Expanded(
      child: RefreshIndicator(
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
                    Text(
                      'Total Earnings',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          e.totalEarnings.toStringAsFixed(0),
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
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
                        _CreatorStatItem(
                          label: 'Total Calls',
                          value: e.totalCalls.toString(),
                          icon: Icons.phone,
                        ),
                        const SizedBox(width: 24),
                        _CreatorStatItem(
                          label: 'Total Minutes',
                          value: e.totalMinutes.toStringAsFixed(1),
                          icon: Icons.timer,
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
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: scheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 8),
          Column(
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
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
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
            imageOrdinal: (entry.key % 9) + 1,
            coins: entry.value.coins,
            price: entry.value.priceInr,
            oldPrice: entry.value.oldPriceInr,
            badge: entry.value.badge,
          ),
        )
        .toList();
    final promoPack = uiPackages.firstWhere(
      (p) => p.oldPrice != null || p.badge != null,
      orElse: () => const _CoinPack(coins: 0, price: 0, imageOrdinal: 1),
    );

    if (uiPackages.isEmpty) {
      return Expanded(
        child: EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'No coin packs available',
          message: 'Please try again shortly',
          actionLabel: 'Retry',
          onAction: onRetry,
        ),
      );
    }

    return Expanded(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        color: Theme.of(context).colorScheme.onSurface,
        backgroundColor: AppBrandGradients.walletRefreshIndicatorBackground,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                          const SizedBox(height: 2),
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
            ),
            if (promoPack.oldPrice != null && promoPack.price > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
                  child: _PromoBanner(
                    coins: promoPack.coins,
                    badge: promoPack.badge,
                    oldPrice: promoPack.oldPrice!,
                    newPrice: promoPack.price,
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.62,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final pack = uiPackages[index];
                  return _CoinPackCard(
                    pack: pack,
                    onTap: isAddingCoins ? null : () => onAddCoins(pack.coins),
                  );
                }, childCount: uiPackages.length),
              ),
            ),
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
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppBrandGradients.walletCoinGold,
            ),
            child: const Center(
              child: Text(
                'e',
                style: TextStyle(
                  color: AppBrandGradients.walletOnGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
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

class _PromoBanner extends StatelessWidget {
  final int coins;
  final String? badge;
  final int oldPrice;
  final int newPrice;
  const _PromoBanner({
    required this.coins,
    required this.oldPrice,
    required this.newPrice,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: AppBrandGradients.walletPromoBanner,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 10,
            bottom: 8,
            child: Opacity(
              opacity: 0.9,
              child: Row(
                children: const [
                  Icon(
                    Icons.account_balance,
                    color: AppBrandGradients.walletPromoIcon,
                    size: 28,
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.flag,
                    color: AppBrandGradients.walletPromoIcon,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge ?? 'Limited-time offer',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(text: '$coins coins  @  '),
                      TextSpan(
                        text: '₹$oldPrice',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const TextSpan(text: '  '),
                      TextSpan(
                        text: '₹$newPrice',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: '  \u00BB\u00BB'),
                    ],
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

class _CoinPack {
  final int imageOrdinal;
  final int coins;
  final int price;
  final int? oldPrice;
  final String? badge;

  const _CoinPack({
    required this.imageOrdinal,
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
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 8, right: 8),
              alignment: Alignment.topRight,
              child: hasDiscount
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '-$discountPercent%',
                        style: TextStyle(
                          color: scheme.onTertiaryContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : const SizedBox(height: 16),
            ),
            const SizedBox(height: 2),
            _CoinPackFirebaseImage(
              ordinal: pack.imageOrdinal,
              size: pack.coins >= 7500 ? 42 : 36,
            ),
            const SizedBox(height: 8),
            Text(
              pack.coins.toString(),
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 27,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'coins',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            if (pack.oldPrice != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '₹${pack.oldPrice}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      decoration: TextDecoration.lineThrough,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '₹${pack.price}',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            else
              Text(
                '₹${pack.price}',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: onTap == null
                    ? scheme.surfaceContainerHighest
                    : scheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Text(
                pack.badge ?? 'Tap to buy',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: onTap == null
                      ? scheme.onSurfaceVariant
                      : scheme.onPrimaryContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoinStackIcon extends StatelessWidget {
  final double size;
  const _CoinStackIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(left: 6, top: 8, child: _coin(context, 0.75)),
          Positioned(right: 6, top: 6, child: _coin(context, 0.9)),
          Positioned(left: size * 0.25, bottom: 0, child: _coin(context, 1)),
        ],
      ),
    );
  }

  Widget _coin(BuildContext context, double scale) {
    final d = size * 0.62 * scale;
    // W4 requirement: no gradients inside grid items.
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.secondaryContainer,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'e',
          style: TextStyle(
            color: scheme.onSecondaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: d * 0.55,
          ),
        ),
      ),
    );
  }
}

class _CoinPackFirebaseImage extends StatelessWidget {
  final int ordinal;
  final double size;

  const _CoinPackFirebaseImage({required this.ordinal, required this.size});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: CoinImageService.getCoinImageUrl(ordinal),
      builder: (context, snapshot) {
        final imageUrl = snapshot.data;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.18),
            child: Image.network(
              imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _CoinStackIcon(size: size),
            ),
          );
        }
        return _CoinStackIcon(size: size);
      },
    );
  }
}
