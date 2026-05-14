import 'package:dio/dio.dart';
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
  Future<WalletPricingData> getWalletPricing({int maxAttempts = 3}) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _apiClient.get('/payment/packages');
        if (response.statusCode == 200 && response.data['success'] == true) {
          final data = response.data['data'] as Map<String, dynamic>;
          return WalletPricingData.fromJson(data);
        }
        final apiError = response.data is Map
            ? (response.data['error']?.toString() ?? 'Unknown error')
            : 'Unknown error';
        throw Exception('Failed to fetch wallet pricing: $apiError');
      } catch (e) {
        lastError = e;
        final retryable = _isRetryablePricingError(e);
        debugPrint(
          '❌ [PAYMENT] Error fetching wallet pricing (attempt $attempt/$maxAttempts): $e',
        );
        if (!retryable || attempt == maxAttempts) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
      }
    }
    throw lastError ?? Exception('Failed to fetch wallet pricing');
  }

  bool _isRetryablePricingError(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.connectionError:
          return true;
        case DioExceptionType.badResponse:
          final status = error.response?.statusCode;
          if (status == 401) return true;
          if (status != null && status >= 500) return true;
          return false;
        default:
          return false;
      }
    }
    return false;
  }
}
