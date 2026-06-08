import '../../../core/api/api_client.dart';
import '../models/vip_models.dart';

class VipApiService {
  final ApiClient _api = ApiClient();

  Future<VipPlansResponse> fetchPlans() async {
    final response = await _api.get('/vip/plan');
    final data = response.data['data'] as Map<String, dynamic>;
    return VipPlansResponse.fromJson(data);
  }

  Future<VipStatus> fetchStatus() async {
    final response = await _api.get('/vip/status');
    final data = response.data['data'] as Map<String, dynamic>;
    return VipStatus.fromJson(data);
  }

  Future<String> initiateCheckout({required String planId}) async {
    final response = await _api.post(
      '/vip/checkout/initiate',
      data: {'planId': planId},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return data['checkoutUrl'] as String;
  }

  Future<void> scheduleCall({
    required String creatorId,
    required DateTime scheduledAt,
    int durationMinutes = 15,
    String? notes,
  }) async {
    await _api.post('/vip/calls/schedule', data: {
      'creatorId': creatorId,
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      'durationMinutes': durationMinutes,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
  }

  Future<List<Map<String, dynamic>>> fetchScheduledCalls() async {
    final response = await _api.get('/vip/calls/scheduled');
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> cancelScheduledCall(String callId) async {
    await _api.post('/vip/calls/scheduled/$callId/cancel');
  }

  Future<List<Map<String, dynamic>>> fetchIncomingScheduledCalls() async {
    final response = await _api.get('/vip/calls/scheduled/incoming');
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> confirmScheduledCall(String callId) async {
    await _api.post('/vip/calls/scheduled/$callId/confirm');
  }

  Future<void> leaveCallQueue(String creatorFirebaseUid) async {
    await _api.delete(
      '/vip/calls/queue',
      data: {'creatorFirebaseUid': creatorFirebaseUid},
    );
  }
}
