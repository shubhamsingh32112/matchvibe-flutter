import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';

/// Persists creator availability intent via REST (Mongo `isOnline` + Redis broadcast).
class CreatorAvailabilityService {
  final ApiClient _apiClient = ApiClient();

  Future<bool> setOnlineStatus(bool isOnline) async {
    debugPrint('📡 [CREATOR AVAILABILITY] PATCH /creator/status isOnline=$isOnline');
    final response = await _apiClient.patch(
      '/creator/status',
      data: {'isOnline': isOnline},
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final data = response.data['data'];
      if (data is Map<String, dynamic>) {
        final creator = data['creator'];
        if (creator is Map<String, dynamic>) {
          return creator['isOnline'] as bool? ?? isOnline;
        }
      }
      return isOnline;
    }

    final error = response.data is Map ? response.data['error'] : null;
    throw Exception(
      error?.toString() ?? 'Failed to update availability (${response.statusCode})',
    );
  }
}
