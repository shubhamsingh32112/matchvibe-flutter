import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoinPopupIntent {
  final String reason;
  final String dedupeKey;

  const CoinPopupIntent({required this.reason, required this.dedupeKey});
}

/// Provider to request coin purchase popups via modal coordinator.
final coinPurchasePopupProvider = StateProvider<CoinPopupIntent?>(
  (ref) => null,
);
