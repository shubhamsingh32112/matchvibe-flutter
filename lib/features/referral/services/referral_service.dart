import '../../../core/api/api_client.dart';
import '../models/referral_model.dart';

class ReferralService {
  final ApiClient _apiClient = ApiClient();

  /// Get current user's referral code and list of referred users.
  Future<ReferralData> getReferrals() async {
    final response = await _apiClient.get('/user/referrals');

    if (response.statusCode == 200 && response.data['success'] == true) {
      return ReferralData.fromJson(response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(response.data['error'] as String? ?? 'Failed to load referrals');
  }
}
