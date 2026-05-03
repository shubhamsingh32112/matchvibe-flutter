import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/widgets/main_layout.dart';
import '../../auth/providers/auth_provider.dart';
import '../../creator/providers/creator_dashboard_provider.dart';
import '../../home/providers/availability_provider.dart';
import '../../video/providers/call_billing_provider.dart';
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
import '../../../shared/widgets/brand_app_chrome.dart';

/// Reference palette (buy-coins marketing screen — matches design spec).
const Color _kBuyCoinsPurple = Color(0xFF7B39FD);
const Color _kBuyCoinsPink = Color(0xFFFF4081);
const Color _kPageBackground = Color(0xFFFFFFFF);
const Color _kTextPrimary = Color(0xFF4A2C5E);
const Color _kTextMuted = Color(0xFF9E9E9E);

/// Left art per sorted pack index (0–5). Filenames match [frontend/lib/assets/wallet_icons].
const List<String> _kWalletTierArt = <String>[
  'lib/assets/wallet_icons/purple_diamonds_pouch_small.png',
  'lib/assets/wallet_icons/blue_diamonds.png',
  'lib/assets/wallet_icons/purple_diamonds.png',
  'lib/assets/wallet_icons/yellow_diamonds.png',
  'lib/assets/wallet_icons/purple_diamonds_pouch_big.png',
  'lib/assets/wallet_icons/diamond_ chest.png',
];

const String _kWalletBuyCoinsHeroAsset =
    'lib/assets/wallet_icons/hero_section.jpeg';

const List<Color> _kTierBadgeColors = <Color>[
  Color(0xFFFF4081),
  Color(0xFF42A5F5),
  Color(0xFF9C27B0),
  Color(0xFFFF9800),
  Color(0xFF8E24AA),
  Color(0xFF7B1FA2),
];

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUserData();
    });
  }

  Future<void> _refreshUserData() async {
    try {
      debugPrint('🔄 [WALLET] Refreshing user data to update balance...');
      await ref.read(authProvider.notifier).refreshUser();
      debugPrint('✅ [WALLET] User data refreshed');
    } catch (e) {
      debugPrint('⚠️  [WALLET] Failed to refresh user data: $e');
    }
  }

  Future<void> _addCoins(int coins) async {
    if (_isAddingCoins) return;

    bool loadingDialogVisible = false;
    setState(() {
      _isAddingCoins = true;
    });

    try {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      loadingDialogVisible = true;

      final checkoutData = await _paymentService.initiateWebCheckout(coins);
      final checkoutUrl = checkoutData['checkoutUrl'] as String;

      if (mounted && loadingDialogVisible) {
        Navigator.of(context).pop();
        loadingDialogVisible = false;
      }

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
      if (mounted && loadingDialogVisible) {
        Navigator.of(context).pop();
        loadingDialogVisible = false;
      }

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
                    const GemIcon(size: 18),
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
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isCreator = user?.role == 'creator' || user?.role == 'admin';
    final billingState = ref.watch(callBillingProvider);
    final coins = billingState.isActive && !isCreator
        ? billingState.userCoins
        : (user?.coins ?? 0);
    final walletPricingAsync =
        isCreator ? null : ref.watch(walletPricingProvider);

    final earningsAsync =
        isCreator ? ref.watch(dashboardEarningsProvider) : null;
    ref.watch(socketServiceProvider);

    if (isCreator) {
      return Scaffold(
        backgroundColor: AppBrandGradients.accountMenuPageBackground,
        appBar: buildBrandAppBar(
          context,
          title: 'Wallet',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          automaticallyImplyLeading: false,
          actions: [
            BrandHeaderCoinsChip(coins: coins),
          ],
        ),
        body: earningsAsync!.when(
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
        ),
      );
    }

    return MainLayout(
      selectedIndex: 0,
      child: AppScaffold(
        // Full-width white sheet (no duplicate horizontal inset vs. inner padding).
        padded: false,
        child: walletPricingAsync!.when(
          data: (pricingData) => SizedBox(
            width: double.infinity,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: ColoredBox(
              color: _kPageBackground,
                child: _UserBuyCoinsBody(
                  isAddingCoins: _isAddingCoins,
                  packages: pricingData.packages.take(6).toList(),
                  onRefresh: () async {
                    await _refreshUserData();
                    ref.invalidate(walletPricingProvider);
                  },
                  onRetry: () => ref.invalidate(walletPricingProvider),
                  onAddCoins: _addCoins,
                ),
              ),
            ),
          ),
          loading: () => const Center(child: LoadingIndicator()),
          error: (error, _) => SingleChildScrollView(
            child: ErrorState(
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
      ),
    );
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
                      const GemIcon(size: 36),
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
              ...e.calls.map(buildCallEarningCard),
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

class _UserBuyCoinsBody extends StatelessWidget {
  final bool isAddingCoins;
  final List<WalletCoinPack> packages;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final void Function(int coins) onAddCoins;

  const _UserBuyCoinsBody({
    required this.isAddingCoins,
    required this.packages,
    required this.onRefresh,
    required this.onRetry,
    required this.onAddCoins,
  });

  @override
  Widget build(BuildContext context) {
    if (packages.isEmpty) {
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
      color: _kBuyCoinsPurple,
      backgroundColor: _kPageBackground,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Image.asset(
                  _kWalletBuyCoinsHeroAsset,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
                if (isAddingCoins)
                  Positioned(
                    right: 20,
                    top: 12,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kBuyCoinsPurple,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final pack = packages[index];
                  final art = index < _kWalletTierArt.length
                      ? _kWalletTierArt[index]
                      : _kWalletTierArt.last;
                  final accent = index < _kTierBadgeColors.length
                      ? _kTierBadgeColors[index]
                      : _kTierBadgeColors.last;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _BuyCoinPackCard(
                      pack: pack,
                      tierArtAsset: art,
                      accentColor: accent,
                      onTap: isAddingCoins
                          ? null
                          : () => onAddCoins(pack.coins),
                    ),
                  );
                },
                childCount: packages.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuyCoinPackCard extends StatelessWidget {
  final WalletCoinPack pack;
  final String tierArtAsset;
  final Color accentColor;
  final VoidCallback? onTap;

  const _BuyCoinPackCard({
    required this.pack,
    required this.tierArtAsset,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDiscount =
        pack.oldPriceInr != null && pack.oldPriceInr! > pack.priceInr;
    final discountPercent = hasDiscount
        ? (((pack.oldPriceInr! - pack.priceInr) / pack.oldPriceInr!) * 100)
            .round()
        : null;
    final String? centerPromo = hasDiscount
        ? (pack.badge != null && pack.badge!.trim().isNotEmpty
            ? pack.badge!.trim()
            : 'Flat $discountPercent% off')
        : (pack.badge != null && pack.badge!.trim().isNotEmpty
            ? pack.badge!.trim()
            : null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFE0E0E0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final artLane =
                        (constraints.maxWidth * 0.40).clamp(102.0, 142.0);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: -4,
                          top: -14,
                          bottom: -14,
                          width: artLane + 22,
                          child: IgnorePointer(
                            child: Image.asset(
                              tierArtAsset,
                              fit: BoxFit.contain,
                              alignment: Alignment.centerLeft,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, _, _) => Align(
                                alignment: Alignment.centerLeft,
                                child: Icon(
                                  Icons.diamond_outlined,
                                  size: 50,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 20,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(width: artLane * 0.72),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '${pack.coins}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                              color: _kTextPrimary,
                                              height: 1.1,
                                            ),
                                          ),
                                          TextSpan(
                                            text: ' Coins',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: _kTextPrimary
                                                  .withValues(alpha: 0.92),
                                              height: 1.1,
                                            ),
                                          ),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (centerPromo != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: hasDiscount
                                                ? _kBuyCoinsPink
                                                    .withValues(alpha: 0.14)
                                                : accentColor
                                                    .withValues(alpha: 0.14),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            centerPromo,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: hasDiscount
                                                  ? _kBuyCoinsPink
                                                      .withValues(alpha: 0.95)
                                                  : accentColor
                                                      .withValues(alpha: 0.95),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 76,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (hasDiscount && discountPercent != null)
                                      Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 5),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _kBuyCoinsPink
                                              .withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '-$discountPercent%',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: _kBuyCoinsPink,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      '₹${pack.priceInr}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: _kBuyCoinsPurple,
                                      ),
                                    ),
                                    if (hasDiscount && pack.oldPriceInr != null)
                                      Text(
                                        '₹${pack.oldPriceInr}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: _kTextMuted,
                                          decoration:
                                              TextDecoration.lineThrough,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
      ),
    );
  }
}
