import '../../../core/api/api_client.dart';
import '../models/creator_leaderboard_model.dart';

class CreatorLeaderboardService {
  final ApiClient _apiClient;

  CreatorLeaderboardService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<CreatorLeaderboardSummary> fetchSummary() async {
    final response = await _apiClient.get('/creator/leaderboard/summary');
    if (response.statusCode == 200 && response.data['success'] == true) {
      final data = response.data['data'] as Map<String, dynamic>;
      return CreatorLeaderboardSummary.fromJson(data);
    }
    throw Exception(
      'Failed to fetch leaderboard summary: ${response.data['error']}',
    );
  }

  Future<CreatorLeaderboardResponse> fetchLeaderboard({
    int limit = 50,
  }) async {
    final response = await _apiClient.get(
      '/creator/leaderboard',
      queryParameters: {'limit': limit},
    );
    if (response.statusCode == 200 && response.data['success'] == true) {
      final data = response.data['data'] as Map<String, dynamic>;
      return CreatorLeaderboardResponse.fromJson(data);
    }
    throw Exception(
      'Failed to fetch leaderboard: ${response.data['error']}',
    );
  }
}
