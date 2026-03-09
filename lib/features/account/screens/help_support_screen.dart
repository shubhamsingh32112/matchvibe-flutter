import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../../shared/widgets/gem_icon.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../wallet/screens/transactions_screen.dart';
import '../../wallet/services/transaction_service.dart';
import '../../wallet/models/transaction_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';

/// Bottom sheet wrapper for help support screen
class HelpSupportBottomSheet extends StatelessWidget {
  const HelpSupportBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => const HelpSupportScreen(),
    );
  }
}

class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  final TransactionService _transactionService = TransactionService();
  TransactionSummary? _summary;
  bool _isLoadingSummary = false;

  @override
  void initState() {
    super.initState();
    _loadTransactionSummary();
  }

  Future<void> _loadTransactionSummary() async {
    final user = ref.read(authProvider).user;
    final isCreator = user?.role == 'creator' || user?.role == 'admin';
    
    // Only load summary for regular users (creators don't have credits/debits/balance)
    if (isCreator) return;

    setState(() {
      _isLoadingSummary = true;
    });

    try {
      final response = await _transactionService.getUserTransactions(page: 1, limit: 1);
      if (mounted) {
        setState(() {
          _summary = response.summary;
          _isLoadingSummary = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSummary = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authProvider).user;
    final isCreator = user?.role == 'creator' || user?.role == 'admin';

    return Container(
      decoration: const BoxDecoration(
        gradient: AppBrandGradients.appBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      'Help & Support',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                // ── Select by Category heading ───────────────────
                Text(
                  'Select by Category',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(height: 16),

                // ── Transaction Summary (Credits, Debits, Balance) ────
                if (!isCreator) ...[
                  if (_isLoadingSummary)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: LoadingIndicator(),
                      ),
                    )
                  else if (_summary != null)
                    _buildTransactionSummaryCard(_summary!, scheme),
                  const SizedBox(height: 16),
                ],

                // ── Recent Payments card ─────────────────────────
                _CategoryCard(
                  iconWidget: const GemIcon(size: 28),
                  title: 'Recent Payments',
                  subtitle: 'View all transactions and raise payment complaints',
                  onTap: () {
                    Navigator.of(context).pop(); // Close help & support bottom sheet
                    // Show transactions bottom sheet
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const TransactionsBottomSheet(),
                    );
                  },
                ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionSummaryCard(TransactionSummary summary, ColorScheme scheme) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: scheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Transaction Summary',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Credits',
                  summary.totalCredits,
                  scheme.primary,
                  Icons.add_circle_outline,
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: scheme.outlineVariant.withOpacity(0.3),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Debits',
                  summary.totalDebits,
                  scheme.error,
                  Icons.remove_circle_outline,
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: scheme.outlineVariant.withOpacity(0.3),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Balance',
                  summary.currentBalance,
                  scheme.primary,
                  Icons.account_balance_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int value, Color color, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label == 'Balance')
              GemIcon(
                color: color,
                size: 16,
              )
            else
              const SizedBox(width: 16),
            Flexible(
              child: Text(
                '$value',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Widget? iconWidget;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CategoryCard({
    this.iconWidget,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        leading: iconWidget,
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: scheme.onSurfaceVariant,
          size: 24,
        ),
        onTap: onTap,
      ),
    );
  }
}
