import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../models/transaction_model.dart';
import '../models/wallet_pricing_model.dart';
import '../utils/transaction_ui_mapper.dart';

class TransactionListItem extends StatelessWidget {
  final TransactionModel transaction;
  final bool isCreator;
  final List<WalletCoinPack> coinPacks;
  final VoidCallback? onTap;

  const TransactionListItem({
    super.key,
    required this.transaction,
    required this.isCreator,
    this.coinPacks = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final info = TransactionUiMapper.displayInfo(
      transaction,
      isCreator: isCreator,
    );
    final isCredit = transaction.type == 'credit';
    final amountColor =
        isCredit ? TransactionUiMapper.creditGreen : TransactionUiMapper.debitRed;
    final prefix = isCredit ? '+' : '-';
    final amountLabel = isCreator
        ? '$prefix${transaction.amount}'
        : '$prefix${transaction.amount} Coins';

    final purchaseInr = !isCreator &&
            transaction.source == 'payment_gateway'
        ? TransactionUiMapper.matchPackPriceInr(
            transaction.amount,
            coinPacks,
          )
        : null;

    final metaParts = <String>[
      TransactionUiMapper.formatRelativeTime(transaction.createdAt),
    ];
    if (purchaseInr != null) {
      metaParts.add('₹$purchaseInr');
    }
  if (!isCreator && transaction.durationFormatted != null) {
      metaParts.insert(0, transaction.durationFormatted!);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: info.accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    info.icon,
                    color: info.accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        info.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppPalette.subtitle,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        metaParts.join(' • '),
                        style: TextStyle(
                          color: AppPalette.subtitle.withValues(alpha: 0.9),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  amountLabel,
                  style: GoogleFonts.poppins(
                    color: amountColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
