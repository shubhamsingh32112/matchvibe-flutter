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

  Future<String> initiateCheckout({required String planId}) async {
    final response = await _api.post(
      '/moments-premium/checkout/initiate',
      data: {'planId': planId},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return data['checkoutUrl'] as String;
  }
}
