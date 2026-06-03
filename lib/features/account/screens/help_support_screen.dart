import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/main_layout.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../../video/providers/call_billing_provider.dart';
import '../../video/providers/call_billing_selectors.dart';
import '../../wallet/models/transaction_model.dart';
import '../../wallet/services/transaction_service.dart';
import '../widgets/help_recent_payments_card.dart';
import '../widgets/help_support_footer_decoration.dart';
import '../widgets/help_support_hero_banner.dart';
import '../widgets/help_transaction_summary_card.dart';

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
    if (isCreator) return;

    setState(() => _isLoadingSummary = true);

    try {
      final response = await _transactionService.getUserTransactions(
        page: 1,
        limit: 1,
      );
      if (mounted) {
        setState(() {
          _summary = response.summary;
          _isLoadingSummary = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingSummary = false);
      }
    }
  }

  void _openTransactions() {
    context.push('/transactions');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider.select((s) => s.user));
    final isCreator = user?.role == 'creator' || user?.role == 'admin';
    final billing = ref.watch(callBillingProvider);
    final coins = shouldShowLiveUserCoins(isCreator: isCreator, billing: billing)
        ? billing.userCoins
        : (user?.coins ?? 0);

    return MainLayout(
      selectedIndex: 4,
      accountMenuStyle: true,
      appBar: buildAccountFlowAppBar(
        context,
        title: 'Help & Support',
        actions: [BrandHeaderCoinsChip(coins: coins)],
      ),
      child: ColoredBox(
        color: AppBrandGradients.accountMenuPageBackground,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: HelpSupportHeroBanner()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  'Select by Category',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ),
            if (!isCreator) ...[
              if (_isLoadingSummary)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Center(child: LoadingIndicator()),
                  ),
                )
              else if (_summary != null)
                SliverToBoxAdapter(
                  child: HelpTransactionSummaryCard(
                    credits: _summary!.totalCredits,
                    debits: _summary!.totalDebits,
                    balance: coins,
                    onTap: _openTransactions,
                  ),
                ),
            ],
            SliverToBoxAdapter(
              child: HelpRecentPaymentsCard(onTap: _openTransactions),
            ),
            const SliverToBoxAdapter(child: HelpSupportFooterDecoration()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],
        ),
      ),
    );
  }
}

/// Legacy wrapper — redirects to full-screen route if still invoked.
class HelpSupportBottomSheet extends StatelessWidget {
  const HelpSupportBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.of(context).pop();
        context.push('/help-support');
      }
    });
    return const SizedBox.shrink();
  }
}
