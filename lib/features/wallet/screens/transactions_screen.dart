import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/main_layout.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/app_modal_bottom_sheet.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/providers/auth_provider.dart';
import '../../support/screens/payment_complaint_screen.dart';
import '../../video/providers/call_billing_provider.dart';
import '../../video/providers/call_billing_selectors.dart';
import '../models/transaction_model.dart';
import '../models/wallet_pricing_model.dart';
import '../providers/wallet_pricing_provider.dart';
import '../services/transaction_service.dart';
import '../utils/transaction_ui_mapper.dart';
import '../widgets/transactions_balance_card.dart';
import '../widgets/transactions_history_section.dart';
import '../widgets/transactions_overview_row.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final TransactionService _transactionService = TransactionService();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _historySectionKey = GlobalKey();

  TransactionResponse? _transactionData;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  final int _limit = 50;
  TransactionFilter _filter = TransactionFilter.all;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletPricingProvider);
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || _isLoading || _transactionData == null) return;
    final pagination = _transactionData!.pagination;
    if (pagination == null) return;

    final totalPages = pagination['totalPages'] as int? ?? 1;
    if (_currentPage >= totalPages) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadTransactions({
    bool refresh = false,
    bool loadMore = false,
  }) async {
    if (refresh) {
      _currentPage = 1;
    }

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
      }
      _error = null;
    });

    try {
      final user = ref.read(authProvider).user;
      final isCreator = user?.role == 'creator' || user?.role == 'admin';

      final response = isCreator
          ? await _transactionService.getCreatorTransactions(
              page: _currentPage,
              limit: _limit,
            )
          : await _transactionService.getUserTransactions(
              page: _currentPage,
              limit: _limit,
            );

      if (mounted) {
        setState(() {
          if (refresh || _transactionData == null) {
            _transactionData = response;
          } else {
            _transactionData = TransactionResponse(
              transactions: [
                ..._transactionData!.transactions,
                ...response.transactions,
              ],
              summary: response.summary ?? _transactionData!.summary,
              pagination: response.pagination,
            );
          }
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = UserMessageMapper.userMessageFor(
            e,
            fallback: 'Couldn\'t load transactions. Please try again.',
          );
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isLoading) return;
    final pagination = _transactionData?.pagination;
    if (pagination == null) return;
    final totalPages = pagination['totalPages'] as int? ?? 1;
    if (_currentPage >= totalPages) return;

    _currentPage += 1;
    await _loadTransactions(loadMore: true);
  }

  void _scrollToHistory() {
    final context = _historySectionKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showPaymentComplaintBottomSheet(TransactionModel transaction) {
    showAppModalBottomSheet(
      context: context,
      builder: (context) =>
          PaymentComplaintBottomSheet(transaction: transaction),
    );
  }

  List<WalletCoinPack> _coinPacks() {
    final pricing = ref.watch(walletPricingProvider).valueOrNull;
    return pricing?.packages ?? const [];
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider.select((s) => s.user));
    final isCreator = user?.role == 'creator' || user?.role == 'admin';
    final billing = ref.watch(callBillingProvider);
    final coins = shouldShowLiveUserCoins(isCreator: isCreator, billing: billing)
        ? billing.userCoins
        : (user?.coins ?? 0);
    final transactions = _transactionData?.transactions ?? const [];
    final overviewStats = TransactionUiMapper.computeOverviewStats(
      transactions,
    );
    final todayNet = TransactionUiMapper.computeTodayNet(transactions);
    final inrEstimate = TransactionUiMapper.estimateInrValue(
      coins,
      _coinPacks(),
    );
    final creatorTotalEarned = transactions
        .where((t) => t.type == 'credit')
        .fold<int>(0, (sum, t) => sum + t.amount);

    return MainLayout(
      selectedIndex: 4,
      accountMenuStyle: true,
      appBar: buildAccountFlowAppBar(
        context,
        title: 'Transactions',
        actions: [BrandHeaderCoinsChip(coins: coins)],
      ),
      child: ColoredBox(
        color: AppBrandGradients.accountMenuPageBackground,
        child: _isLoading && _transactionData == null
            ? const Center(child: LoadingIndicator())
            : _error != null && _transactionData == null
            ? ErrorState(
                title: 'Failed to load transactions',
                message: _error ?? 'Unknown error',
                actionLabel: 'Retry',
                onAction: () => _loadTransactions(refresh: true),
              )
            : RefreshIndicator(
                onRefresh: () => _loadTransactions(refresh: true),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
                    if (!isCreator) ...[
                      SliverToBoxAdapter(
                        child: TransactionsBalanceCard(
                          coins: coins,
                          todayNet: todayNet,
                          inrEstimate: inrEstimate,
                          onScrollToHistory: _scrollToHistory,
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.md),
                      ),
                      SliverToBoxAdapter(
                        child: TransactionsOverviewRow(stats: overviewStats),
                      ),
                    ] else ...[
                      SliverToBoxAdapter(
                        child: TransactionsCreatorBalanceCard(
                          totalEarned: creatorTotalEarned,
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.lg),
                      ),
                    ],
                    if (_transactionData == null ||
                        _transactionData!.transactions.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyView(isCreator),
                      )
                    else ...[
                      ...TransactionsHistorySection.buildSlivers(
                        context: context,
                        historySectionKey: _historySectionKey,
                        transactions: transactions,
                        filter: _filter,
                        onFilterChanged: (value) {
                          setState(() => _filter = value);
                        },
                        isCreator: isCreator,
                        coinPacks: _coinPacks(),
                        onTransactionTap: isCreator
                            ? null
                            : _showPaymentComplaintBottomSheet,
                      ),
                      if (_isLoadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.lg),
                            child: Center(child: LoadingIndicator()),
                          ),
                        ),
                      const SliverToBoxAdapter(
                        child: TransactionsFooterDecoration(),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyView(bool isCreator) {
    return EmptyState(
      icon: isCreator
          ? Icons.account_balance_wallet_outlined
          : Icons.receipt_long_outlined,
      title: isCreator ? 'No earnings yet' : 'No transactions yet',
      message: isCreator
          ? 'Your earnings from video calls will appear here'
          : 'Your coin transactions will appear here',
    );
  }
}

/// Legacy wrapper — redirects to full-screen route if still invoked.
class TransactionsBottomSheet extends StatelessWidget {
  const TransactionsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.of(context).pop();
        context.push('/transactions');
      }
    });
    return const SizedBox.shrink();
  }
}
