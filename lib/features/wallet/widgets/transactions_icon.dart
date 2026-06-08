import 'package:flutter/material.dart';

import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/decorative_asset_image.dart';
import '../constants/transaction_assets.dart';

/// Transactions icon for account menu tiles and inline labels.
class TransactionsIcon extends StatelessWidget {
  final double size;

  const TransactionsIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return DecorativeAssetImage(
      assetPath: TransactionAssets.menuIcon,
      width: size,
      height: size,
      fallbackIcon: Icons.receipt_long_outlined,
      fallbackIconSize: size,
      fallbackIconColor: AppBrandGradients.accountMenuIconTint,
    );
  }
}
