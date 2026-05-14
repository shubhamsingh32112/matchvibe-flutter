import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wallet_pricing_model.dart';
import '../services/payment_service.dart';

final walletPricingProvider = FutureProvider<WalletPricingData>((ref) async {
  return PaymentService().getWalletPricing();
});

/// Warm coin-pack pricing before the buy-coins modal opens.
Future<void> prefetchWalletPricing(
  dynamic ref, {
  bool forceRefresh = false,
}) async {
  if (forceRefresh) {
    ref.invalidate(walletPricingProvider);
  }
  try {
    await ref.read(walletPricingProvider.future);
  } catch (e) {
    debugPrint('⚠️ [WALLET] Pricing prefetch failed: $e');
  }
}

void warmWalletPricingCache(dynamic ref) {
  unawaited(prefetchWalletPricing(ref));
}
