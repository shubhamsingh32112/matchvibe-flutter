import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/transaction_service.dart';
import '../models/transaction_model.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../../shared/widgets/gem_icon.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/app_modal_bottom_sheet.dart';
import '../../support/screens/payment_complaint_screen.dart';

/// Bottom sheet wrapper for transactions screen
class TransactionsBottomSheet extends StatelessWidget {
  const TransactionsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => const TransactionsScreen(),
    );
  }
}

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final TransactionService _transactionService = TransactionService();
  TransactionResponse? _transactionData;
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  final int _limit = 50;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = ref.read(authProvider).user;
      final isCreator = user?.role == 'creator' || user?.role == 'admin';

      final response = isCreator
          ? await _transactionService.getCreatorTransactions(page: _currentPage, limit: _limit)
          : await _transactionService.getUserTransactions(page: _currentPage, limit: _limit);

      if (mounted) {
        setState(() {
          if (refresh || _transactionData == null) {
            _transactionData = response;
          } else {
            // Append new transactions for pagination
            _transactionData = TransactionResponse(
              transactions: [..._transactionData!.transactions, ...response.transactions],
              summary: response.summary ?? _transactionData!.summary,
              pagination: response.pagination,
            );
          }
          _isLoading = false;
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
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isCreator = user?.role == 'creator' || user?.role == 'admin';
    final coins = user?.coins ?? 0;
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
                      'Transactions',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!isCreator)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GemIcon(color: scheme.primary, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '$coins',
                            style: TextStyle(
                              color: scheme.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Summary Card (for users)
            if (!isCreator && _transactionData?.summary != null)
              _buildSummaryCard(_transactionData!.summary!),
            // Transactions List
            Expanded(
              child: _isLoading && _transactionData == null
                  ? const Center(child: LoadingIndicator())
                  : _error != null
                      ? ErrorState(
                          title: 'Failed to load transactions',
                          message: _error ?? 'Unknown error',
                          actionLabel: 'Retry',
                          onAction: () => _loadTransactions(refresh: true),
                        )
                      : _transactionData == null || _transactionData!.transactions.isEmpty
                          ? _buildEmptyView(isCreator)
                          : _buildTransactionsList(isCreator),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(TransactionSummary summary) {
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Credits', summary.totalCredits, Theme.of(context).colorScheme.primary),
          _buildSummaryItem('Debits', summary.totalDebits, Theme.of(context).colorScheme.error),
          _buildSummaryItem('Balance', summary.currentBalance, Theme.of(context).colorScheme.primary),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int value, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyView(bool isCreator) {
    return EmptyState(
      icon: isCreator ? Icons.account_balance_wallet_outlined : Icons.receipt_long_outlined,
      title: isCreator ? 'No earnings yet' : 'No transactions yet',
      message: isCreator
          ? 'Your earnings from video calls will appear here'
          : 'Your coin transactions will appear here',
    );
  }

  Widget _buildTransactionsList(bool isCreator) {
    return RefreshIndicator(
      onRefresh: () => _loadTransactions(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _transactionData!.transactions.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _transactionData!.transactions.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: LoadingIndicator(),
              ),
            );
          }

          final transaction = _transactionData!.transactions[index];
          return _buildTransactionCard(transaction, isCreator);
        },
      ),
    );
  }

  Widget _buildTransactionCard(TransactionModel transaction, bool isCreator) {
    final scheme = Theme.of(context).colorScheme;
    final isCredit = transaction.type == 'credit';
    final color = isCredit ? scheme.primary : scheme.error;
    final icon = isCredit ? Icons.add_circle : Icons.remove_circle;
    final prefix = isCredit ? '+' : '-';

    // Allow complaints for all transactions (not just payment transactions)
    final canComplain = !isCreator;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      onTap: canComplain
          ? () => _showPaymentComplaintBottomSheet(transaction)
          : null,
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description ?? (isCreator ? 'Video call earnings' : 'Transaction'),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (isCreator && transaction.callerUsername != null) ...[
                      Text(
                        'With ${transaction.callerUsername}',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (transaction.durationFormatted != null) ...[
                      Text(
                        '• ${transaction.durationFormatted}',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      _formatDate(transaction.createdAt),
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                    ),
                    if (canComplain) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• Tap to complain',
                        style: TextStyle(
                          color: scheme.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$prefix${transaction.amount}',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isCredit ? 'Earned' : 'Spent',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showPaymentComplaintBottomSheet(TransactionModel transaction) {
    showAppModalBottomSheet(
      context: context,
      builder: (context) =>
          PaymentComplaintBottomSheet(transaction: transaction),
    );
  }
}
