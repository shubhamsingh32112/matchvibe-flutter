import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wallet_pricing_model.dart';
import '../services/payment_service.dart';

final walletPricingProvider = FutureProvider<WalletPricingData>((ref) async {
  return PaymentService().getWalletPricing();
});

