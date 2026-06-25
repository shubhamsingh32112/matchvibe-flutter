import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/moments_models.dart';
import '../models/playback_refresh_models.dart';

class MomentsApiService {
  final ApiClient _api = ApiClient();

  Future<MomentsFeedPage> fetchFeed({
    String? cursor,
    int limit = 20,
  }) async {
    final response = await _api.get(
      '/moments/feed',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final raw = data['items'] as List? ?? const [];
    return MomentsFeedPage(
      items: raw
          .map((e) => MomentFeedItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      sections: MomentsFeedSections.fromJson(
        data['sections'] as Map<String, dynamic>?,
      ),
      nextCursor: data['nextCursor'] as String?,
    );
  }

  Future<MomentsFeedPage> fetchFollowingFeed({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _api.get(
      '/moments/following',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final raw = data['items'] as List? ?? const [];
    return MomentsFeedPage(
      items: raw
          .map((e) => MomentFeedItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      sections: MomentsFeedSections.fromJson(
        data['sections'] as Map<String, dynamic>?,
      ),
      hasMore: data['hasMore'] as bool? ?? false,
      nextOffset: data['nextOffset'] as int? ?? offset,
    );
  }

  Future<MomentFeedItem> fetchMomentDetail(String momentId) async {
    final response = await _api.get('/moments/$momentId');
    return MomentFeedItem.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  Future<void> recordPaywallShown({
    required String source,
    String? momentId,
  }) async {
    try {
      await _api.post(
        '/moments/analytics/paywall-shown',
        data: {
          'source': source,
          if (momentId != null) 'momentId': momentId,
        },
      );
    } catch (_) {
      // Non-blocking analytics
    }
  }

  /// @deprecated Coin unlock removed — server returns 403 MOMENTS_PREMIUM_REQUIRED.
  Future<MomentFeedItem> purchase(String momentId, {String? transactionId}) async {
    final response = await _api.post(
      '/moments/$momentId/purchase',
      data: transactionId != null
          ? {'transactionId': transactionId}
          : <String, dynamic>{},
    );
    return MomentFeedItem.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  Future<PlaybackRefreshResult> refreshPlayback(String momentId) async {
    try {
      final response = await _api.post('/moments/$momentId/playback');
      return _parsePlaybackRefreshResponse(response);
    } on DioException catch (e) {
      throw _mapPlaybackRefreshError(e);
    }
  }

  Future<void> completeMoment(
    String momentId, {
    required int watchedPct,
    required bool completed,
  }) async {
    await _api.post('/moments/$momentId/complete', data: {
      'watchedPct': watchedPct,
      'completed': completed,
    });
  }

  Future<int> recordMomentView(String momentId) async {
    final response = await _api.post('/moments/$momentId/view');
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    return data['viewsCount'] as int? ?? 0;
  }

  Future<({bool isFollowing, int followerCount})> followCreator(
    String creatorId,
  ) async {
    final response = await _api.post('/moments/creators/$creatorId/follow');
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    return (
      isFollowing: data['isFollowing'] as bool? ?? true,
      followerCount: data['followerCount'] as int? ?? 0,
    );
  }

  Future<({bool isFollowing, int followerCount})> unfollowCreator(
    String creatorId,
  ) async {
    final response = await _api.delete('/moments/creators/$creatorId/follow');
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    return (
      isFollowing: data['isFollowing'] as bool? ?? false,
      followerCount: data['followerCount'] as int? ?? 0,
    );
  }

  Future<List<String>> fetchFollowingList() async {
    final response = await _api.get('/moments/following/list');
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final raw = data['creatorIds'] as List? ?? const [];
    return raw.map((e) => e.toString()).toList();
  }

  Future<CreatorSummary> fetchCreatorSummary(String creatorId) async {
    final response = await _api.get('/moments/creators/$creatorId/summary');
    return CreatorSummary.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  Future<List<MomentFeedItem>> fetchCreatorMoments(String creatorId) async {
    final response = await _api.get('/moments/creator/$creatorId');
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final raw = data['items'] as List? ?? const [];
    return raw
        .map((e) => MomentFeedItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<MomentFeedItem>> fetchMyMoments() async {
    final response = await _api.get('/moments/creator/me');
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final raw = data['items'] as List? ?? const [];
    return raw
        .map((e) => MomentFeedItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> deleteMoment(String momentId) async {
    await _api.delete('/moments/$momentId');
  }

  Future<Map<String, dynamic>> fetchCreatorAnalytics() async {
    final response = await _api.get('/moments/creator/me/analytics');
    return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
  }

  Future<void> createStory({
    required String type,
    String? imageSessionId,
    String? streamSessionId,
    String? caption,
  }) async {
    await _api.post('/stories', data: {
      'type': type,
      if (imageSessionId != null) 'imageSessionId': imageSessionId,
      if (streamSessionId != null) 'streamSessionId': streamSessionId,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
    });
  }

  Future<int> createMoment({
    required String type,
    String? imageSessionId,
    String? streamSessionId,
    String? thumbnailSessionId,
    String? caption,
  }) async {
    final response = await _api.post('/moments', data: {
      'type': type,
      if (imageSessionId != null) 'imageSessionId': imageSessionId,
      if (streamSessionId != null) 'streamSessionId': streamSessionId,
      if (thumbnailSessionId != null) 'thumbnailSessionId': thumbnailSessionId,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
    });
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    return (data['uploadRewardCoins'] as num?)?.toInt() ?? 0;
  }
}

class StoriesApiService {
  final ApiClient _api = ApiClient();

  Future<List<StoryGroup>> fetchStoryFeed() async {
    final response = await _api.get('/stories/feed');
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final raw = data['groups'] as List? ?? const [];
    return raw
        .map((e) => StoryGroup.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<StoryPresentation>> fetchMyStories() async {
    final response = await _api.get('/stories/creator/me');
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final raw = data['stories'] as List? ?? const [];
    return raw
        .map((e) => StoryPresentation.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> recordStoryView(String storyId) async {
    final response = await _api.post('/stories/$storyId/view');
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    return data['viewsCount'] as int? ?? 0;
  }

  Future<void> deleteStory(String storyId) async {
    await _api.delete('/stories/$storyId');
  }

  Future<PlaybackRefreshResult> refreshPlayback(String storyId) async {
    try {
      final response = await _api.post('/stories/$storyId/playback');
      return _parsePlaybackRefreshResponse(response);
    } on DioException catch (e) {
      throw _mapPlaybackRefreshError(e);
    }
  }

  Future<void> completeStory(
    String storyId, {
    required int watchedPct,
    required bool completed,
  }) async {
    await _api.post('/stories/$storyId/complete', data: {
      'watchedPct': watchedPct,
      'completed': completed,
    });
  }

  Future<({int viewsCount, List<StoryViewer> viewers})> fetchStoryViewers(
    String storyId,
  ) async {
    final response = await _api.get('/stories/$storyId/viewers');
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final raw = data['viewers'] as List? ?? const [];
    return (
      viewsCount: data['viewsCount'] as int? ?? 0,
      viewers: raw
          .map((e) => StoryViewer.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

PlaybackRefreshResult _parsePlaybackRefreshResponse(Response<dynamic> response) {
  final data = response.data;
  if (data is! Map) {
    throw PlaybackRefreshException('Invalid playback refresh response');
  }
  final root = Map<String, dynamic>.from(data);
  if (root['success'] != true) {
    final code = root['code']?.toString();
    throw PlaybackRefreshException(
      root['error']?.toString() ?? 'Playback refresh failed',
      statusCode: response.statusCode,
      code: code,
    );
  }
  final payload = Map<String, dynamic>.from(root['data'] as Map? ?? {});
  return PlaybackRefreshResult(
    playbackUrl: payload['playbackUrl'] as String? ?? '',
    expiresAtMs: (payload['expiresAt'] as num?)?.toInt() ?? 0,
  );
}

PlaybackRefreshException _mapPlaybackRefreshError(DioException e) {
  final status = e.response?.statusCode;
  final body = e.response?.data;
  String? code;
  var message = e.message ?? 'Playback refresh failed';
  if (body is Map) {
    code = body['code']?.toString();
    message = body['error']?.toString() ?? message;
  }
  return PlaybackRefreshException(message, statusCode: status, code: code);
}
