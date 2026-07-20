import '../../../core/api/api_client.dart';
import '../models/moments_premium_models.dart';

class MomentsPremiumApiService {
  final ApiClient _api = ApiClient();

  Future<MomentsPremiumPlansResponse> fetchPlans() async {
    final response = await _api.get('/moments-premium/plan');
    final data = response.data['data'] as Map<String, dynamic>;
    return MomentsPremiumPlansResponse.fromJson(data);
  }

  Future<MomentsPremiumStatus> fetchStatus() async {
    final response = await _api.get('/moments-premium/status');
    final data = response.data['data'] as Map<String, dynamic>;
    return MomentsPremiumStatus.fromJson(data);
  }

  /// Returns checkout handoff fields used for browser launch + Meta Purchase.
  Future<Map<String, dynamic>> initiateCheckout({required String planId}) async {
    final response = await _api.post(
      '/moments-premium/checkout/initiate',
      data: {'planId': planId},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return {
      'checkoutUrl': data['checkoutUrl'] as String,
      'sessionId': data['sessionId'] as String? ?? '',
      'planId': data['planId'] as String? ?? planId,
      'priceInr': (data['priceInr'] as num?)?.toInt() ?? 0,
    };
  }
}
