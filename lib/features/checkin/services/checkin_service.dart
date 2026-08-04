import 'package:flutter/foundation.dart';
import '../../../core/api/api_client.dart';
import '../models/checkin_status_model.dart';

class CheckInService {
  final ApiClient _apiClient = ApiClient();

  Future<CheckInStatus> getStatus() async {
    final response = await _apiClient.get('/user/check-in/status');
    if (response.statusCode == 200 && response.data['success'] == true) {
      return CheckInStatus.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    }
    throw Exception(
      response.data['error']?.toString() ?? 'Failed to load check-in status',
    );
  }

  Future<CheckInStatus> claim() async {
    final response = await _apiClient.post('/user/check-in/claim');
    if (response.statusCode == 200 && response.data['success'] == true) {
      return CheckInStatus.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    }
    throw Exception(
      response.data['error']?.toString() ?? 'Failed to claim check-in',
    );
  }

  Future<void> registerPushToken({
    required String token,
    required String platform,
  }) async {
    try {
      await _apiClient.post(
        '/user/check-in/push-token',
        data: {'token': token, 'platform': platform},
      );
    } catch (e) {
      debugPrint('⚠️ [CHECKIN] registerPushToken failed: $e');
    }
  }

  Future<void> unregisterPushToken(String token) async {
    try {
      await _apiClient.delete(
        '/user/check-in/push-token',
        data: {'token': token},
      );
    } catch (e) {
      debugPrint('⚠️ [CHECKIN] unregisterPushToken failed: $e');
    }
  }
}
