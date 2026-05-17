import '../../../core/api/api_client.dart';

class HostOnboardingException implements Exception {
  final String message;
  HostOnboardingException(this.message);

  @override
  String toString() => message;
}

class HostOnboardingService {
  final ApiClient _apiClient = ApiClient();

  Future<void> completeHostProfile({
    required String name,
    required String about,
    required String avatarUploadSessionId,
    List<String>? categories,
    String? location,
  }) async {
    final response = await _apiClient.post(
      '/user/host-profile/complete',
      data: {
        'name': name.trim(),
        'about': about.trim(),
        'avatarUploadSessionId': avatarUploadSessionId,
        if (categories != null && categories.isNotEmpty) 'categories': categories,
        if (location != null && location.trim().isNotEmpty) 'location': location.trim(),
      },
    );

    if (response.statusCode == 201 && response.data['success'] == true) {
      return;
    }

    final err = response.data['error'] as String?;
    throw HostOnboardingException(
      err ?? 'Could not complete host profile. Try again.',
    );
  }
}
