import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to control when the coin purchase pop-up should be shown.
final coinPurchasePopupProvider = StateProvider<bool>((ref) => false);

/// Helper function to show the coin purchase pop-up.
void showCoinPurchasePopup(WidgetRef ref) {
  ref.read(coinPurchasePopupProvider.notifier).state = true;
}

/// Helper function to hide the coin purchase pop-up.
void hideCoinPurchasePopup(WidgetRef ref) {
  ref.read(coinPurchasePopupProvider.notifier).state = false;
}
