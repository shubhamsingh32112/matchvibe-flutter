import '../../core/api/api_client.dart';
import '../models/app_update_model.dart';

class AppUpdateService {
  final ApiClient _apiClient = ApiClient();

  Future<AppUpdateModel?> getPendingUpdate() async {
    final res = await _apiClient.get('/app-updates/pending');
    final data = res.data;
    if (data is! Map || data['success'] != true || data['data'] == null) {
      return null;
    }
    final payload = data['data'];
    if (payload is! Map<String, dynamic>) return null;
    return AppUpdateModel.fromJson(payload);
  }

  Future<void> ackUpdateNow(String updateId) async {
    await _apiClient.post('/app-updates/$updateId/ack-update-now');
  }
}
