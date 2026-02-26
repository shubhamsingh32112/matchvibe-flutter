import 'package:flutter/foundation.dart';
import '../../../core/api/api_client.dart';
import '../models/wallet_pricing_model.dart';

/// Service for wallet payment handoff.
/// Razorpay order creation/verification is handled by website + backend only.
class PaymentService {
  final ApiClient _apiClient = ApiClient();

  /// Start web checkout flow. Returns the checkout URL to open in browser.
  Future<Map<String, dynamic>> initiateWebCheckout(int coins) async {
    try {
      debugPrint('🌐 [PAYMENT] Initiating web checkout for $coins coins...');
      final response = await _apiClient.post(
        '/payment/web/initiate',
        data: {'coins': coins},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        return {
          'checkoutUrl': data['checkoutUrl'] as String,
          'coins': data['coins'] as int,
          'amount': data['amount'] as int,
          'priceInr': data['priceInr'] as int,
        };
      } else {
        throw Exception(
          'Failed to initiate web checkout: ${response.data['error'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      debugPrint('❌ [PAYMENT] Error initiating web checkout: $e');
      rethrow;
    }
  }

  /// Fetch wallet coin packs and effective user pricing tier from backend.
  Future<WalletPricingData> getWalletPricing() async {
    try {
      final response = await _apiClient.get('/payment/packages');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        return WalletPricingData.fromJson(data);
      }
      throw Exception(
        'Failed to fetch wallet pricing: ${response.data['error'] ?? 'Unknown error'}',
      );
    } catch (e) {
      debugPrint('❌ [PAYMENT] Error fetching wallet pricing: $e');
      rethrow;
    }
  }
}
