import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../models/rewards_hub_models.dart';

class RewardsHubService {
  final ApiClient _api = ApiClient();

  Future<RewardsHubData> getHub() async {
    try {
      final response = await _api.get('/rewards/hub');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return RewardsHubData.fromJson(
          response.data['data'] as Map<String, dynamic>,
        );
      }
      throw Exception(
        response.data['error']?.toString() ?? 'Failed to load rewards',
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }
      rethrow;
    }
  }

  Future<RewardsClaimResult> claim(String taskKey) async {
    try {
      final response = await _api.post('/rewards/tasks/$taskKey/claim');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return RewardsClaimResult.fromJson(
          response.data['data'] as Map<String, dynamic>,
        );
      }
      throw Exception(
        response.data['error']?.toString() ?? 'Failed to claim reward',
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }
      rethrow;
    }
  }
}
