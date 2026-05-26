import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/decorative_asset_image.dart';
import '../constants/transaction_assets.dart';
import '../models/transaction_model.dart';
import '../models/wallet_pricing_model.dart';
import '../utils/transaction_ui_mapper.dart';
import 'transaction_list_item.dart';

class TransactionsHistorySection {
  TransactionsHistorySection._();

  static List<Widget> buildSlivers({
    required BuildContext context,
    required GlobalKey historySectionKey,
    required List<TransactionModel> transactions,
    required TransactionFilter filter,
    required ValueChanged<TransactionFilter> onFilterChanged,
    required bool isCreator,
    required List<WalletCoinPack> coinPacks,
    required void Function(TransactionModel transaction)? onTransactionTap,
  }) {
    final filtered = TransactionUiMapper.applyFilter(transactions, filter);
    final grouped = TransactionUiMapper.groupByDateHeader(filtered);

    final slivers = <Widget>[
      SliverToBoxAdapter(
        key: historySectionKey,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isCreator ? 'Earnings History' : 'Transaction History',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2D2D2D),
                      ),
                ),
              ),
              _FilterChip(
                filter: filter,
                onChanged: onFilterChanged,
                isCreator: isCreator,
              ),
            ],
          ),
        ),
      ),
    ];

    if (filtered.isEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            child: Center(
              child: Text(
                isCreator
                    ? 'No earnings match this filter'
                    : 'No transactions match this filter',
                style: TextStyle(color: AppPalette.subtitle),
              ),
            ),
          ),
        ),
      );
      return slivers;
    }

    for (final entry in grouped.entries) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text(
              entry.key,
              style: const TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final tx = entry.value[index];
                return TransactionListItem(
                  transaction: tx,
                  isCreator: isCreator,
                  coinPacks: coinPacks,
                  onTap: onTransactionTap != null
                      ? () => onTransactionTap(tx)
                      : null,
                );
              },
              childCount: entry.value.length,
            ),
          ),
        ),
      );
    }

    return slivers;
  }
}

class TransactionsFooterDecoration extends StatelessWidget {
  const TransactionsFooterDecoration({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      child: Center(
        child: DecorativeAssetImage(
          assetPath: TransactionAssets.walletFooter,
          height: 148,
          fallbackIcon: Icons.account_balance_wallet_outlined,
          fallbackIconSize: 48,
          fallbackIconColor: AppBrandGradients.accountMenuIconTint.withValues(
            alpha: 0.25,
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final TransactionFilter filter;
  final ValueChanged<TransactionFilter> onChanged;
  final bool isCreator;

  const _FilterChip({
    required this.filter,
    required this.onChanged,
    required this.isCreator,
  });

  List<TransactionFilter> get _options {
    if (isCreator) {
      return const [
        TransactionFilter.all,
        TransactionFilter.credits,
      ];
    }
    return TransactionFilter.values;
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TransactionFilter>(
      initialValue: filter,
      onSelected: onChanged,
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              filter.label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 18),
          ],
        ),
      ),
      itemBuilder: (context) => _options
          .map(
            (option) => PopupMenuItem<TransactionFilter>(
              value: option,
              child: Text(option.label),
            ),
          )
          .toList(),
    );
  }
}
