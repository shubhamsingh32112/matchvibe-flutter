import '../api/api_client.dart';
import 'app_config_model.dart';

class AppConfigService {
  final ApiClient _apiClient = ApiClient();

  Future<AppConfig> fetch() async {
    final res = await _apiClient.get('/app-config');
    final data = res.data;
    if (data is! Map || data['success'] != true || data['data'] == null) {
      return AppConfig.safeDefaults();
    }
    final payload = data['data'];
    if (payload is! Map<String, dynamic>) {
      return AppConfig.safeDefaults();
    }
    return AppConfig.fromJson(payload);
  }
}
