import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/moments_models.dart';
import '../services/moments_api_service.dart';

bool _momentsEnabled(Ref ref) => ref.watch(appFeaturesProvider).momentsEnabled;

class MomentsCapabilities {
  const MomentsCapabilities({
    required this.isPremium,
    required this.canUpload,
    required this.canManageOwn,
    required this.showPremiumButton,
    required this.showFloatingCta,
  });

  final bool isPremium;
  final bool canUpload;
  final bool canManageOwn;
  final bool showPremiumButton;
  final bool showFloatingCta;
}

final momentsCapabilitiesProvider = Provider<MomentsCapabilities>((ref) {
  final user = ref.watch(authProvider.select((s) => s.user));
  final isPremium = user?.isMomentsPremiumActive ?? false;
  final role = user?.role;
  final tab = ref.watch(momentsFeedTabProvider);
  final feedAsync = tab == MomentsFeedTab.popular
      ? ref.watch(popularFeedProvider)
      : ref.watch(followingFeedProvider);
  final feedHasLocked =
      feedAsync.valueOrNull?.any((item) => item.locked) ?? false;

  return MomentsCapabilities(
    isPremium: isPremium,
    canUpload: role == 'creator' || role == 'admin',
    canManageOwn: role == 'creator' || role == 'admin',
    showPremiumButton: !isPremium && role != 'creator' && role != 'admin',
    showFloatingCta: !isPremium && feedHasLocked,
  );
});

enum MomentsFeedTab { popular, following }

enum MomentsMediaFilter { all, photos, videos }

final momentsFeedTabProvider = StateProvider<MomentsFeedTab>(
  (ref) => MomentsFeedTab.popular,
);

final momentsMediaFilterProvider = StateProvider<MomentsMediaFilter>(
  (ref) => MomentsMediaFilter.all,
);

List<MomentFeedItem> applyMediaFilter(
  List<MomentFeedItem> items,
  MomentsMediaFilter filter,
) {
  switch (filter) {
    case MomentsMediaFilter.photos:
      return items.where((i) => !i.media.isVideo).toList();
    case MomentsMediaFilter.videos:
      return items.where((i) => i.media.isVideo).toList();
    case MomentsMediaFilter.all:
      return items;
  }
}

final storiesBarProvider = FutureProvider<List<StoryGroup>>((ref) async {
  if (!_momentsEnabled(ref)) return [];
  return StoriesApiService().fetchStoryFeed();
});

final followingCreatorsProvider = FutureProvider<Set<String>>((ref) async {
  if (!_momentsEnabled(ref)) return {};
  final ids = await MomentsApiService().fetchFollowingList();
  return ids.toSet();
});

final creatorSummaryProvider =
    FutureProvider.family<CreatorSummary, String>((ref, creatorId) async {
  if (!_momentsEnabled(ref)) {
    return CreatorSummary(
      creatorId: creatorId,
      followerCount: 0,
      followingCount: 0,
      postCount: 0,
      isFollowing: false,
    );
  }
  return MomentsApiService().fetchCreatorSummary(creatorId);
});

final creatorMomentsProvider =
    FutureProvider.family<List<MomentFeedItem>, String>((ref, creatorId) async {
  if (!_momentsEnabled(ref)) return [];
  return MomentsApiService().fetchCreatorMoments(creatorId);
});

final myStoriesProvider = FutureProvider<List<StoryPresentation>>((ref) async {
  if (!_momentsEnabled(ref)) return [];
  return StoriesApiService().fetchMyStories();
});

final myMomentsProvider = FutureProvider<List<MomentFeedItem>>((ref) async {
  if (!_momentsEnabled(ref)) return [];
  return MomentsApiService().fetchMyMoments();
});

class FollowingFeedNotifier extends AsyncNotifier<List<MomentFeedItem>> {
  int _nextOffset = 0;
  bool _hasMore = true;
  bool _loadingMore = false;

  @override
  Future<List<MomentFeedItem>> build() async {
    if (!ref.watch(appFeaturesProvider).momentsEnabled) return [];
    final result = await MomentsApiService().fetchFollowingFeed();
    _nextOffset = result.nextOffset;
    _hasMore = result.hasMore;
    return result.items;
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    try {
      final result = await MomentsApiService().fetchFollowingFeed(
        offset: _nextOffset,
      );
      _nextOffset = result.nextOffset;
      _hasMore = result.hasMore;
      final current = state.value ?? [];
      state = AsyncData([...current, ...result.items]);
    } finally {
      _loadingMore = false;
    }
  }

  void updateItem(int index, MomentFeedItem item) {
    final current = [...?state.value];
    if (index < 0 || index >= current.length) return;
    current[index] = item;
    state = AsyncData(current);
  }

  void patchFollowStateForCreator(String creatorId, bool isFollowing) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current
          .map(
            (item) => item.creatorId == creatorId
                ? item.copyWith(isFollowing: isFollowing)
                : item,
          )
          .toList(),
    );
  }
}

final followingFeedProvider =
    AsyncNotifierProvider<FollowingFeedNotifier, List<MomentFeedItem>>(
  FollowingFeedNotifier.new,
);

class PopularFeedNotifier extends AsyncNotifier<List<MomentFeedItem>> {
  String? _nextCursor;
  bool _loadingMore = false;

  @override
  Future<List<MomentFeedItem>> build() async {
    if (!ref.watch(appFeaturesProvider).momentsEnabled) return [];
    final result = await MomentsApiService().fetchFeed();
    _nextCursor = result.nextCursor;
    return result.items;
  }

  Future<void> loadMore() async {
    if (_loadingMore || _nextCursor == null) return;
    _loadingMore = true;
    try {
      final result = await MomentsApiService().fetchFeed(cursor: _nextCursor);
      _nextCursor = result.nextCursor;
      final current = state.value ?? [];
      state = AsyncData([...current, ...result.items]);
    } finally {
      _loadingMore = false;
    }
  }

  void updateItem(int index, MomentFeedItem item) {
    final current = [...?state.value];
    if (index < 0 || index >= current.length) return;
    current[index] = item;
    state = AsyncData(current);
  }

  void patchFollowStateForCreator(String creatorId, bool isFollowing) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current
          .map(
            (item) => item.creatorId == creatorId
                ? item.copyWith(isFollowing: isFollowing)
                : item,
          )
          .toList(),
    );
  }
}

final popularFeedProvider =
    AsyncNotifierProvider<PopularFeedNotifier, List<MomentFeedItem>>(
  PopularFeedNotifier.new,
);

final creatorMomentsAnalyticsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  if (!_momentsEnabled(ref)) return {};
  return MomentsApiService().fetchCreatorAnalytics();
});

/// Tracks pending stream upload session ids waiting for media:ready socket.
final pendingMediaSessionsProvider =
    StateProvider<Set<String>>((ref) => {});

void invalidateMomentsFeeds(Ref ref) {
  ref.invalidate(storiesBarProvider);
  ref.invalidate(followingFeedProvider);
  ref.invalidate(popularFeedProvider);
  ref.invalidate(myStoriesProvider);
  ref.invalidate(myMomentsProvider);
  ref.invalidate(creatorMomentsAnalyticsProvider);
  // Creator profile grids fetch /moments/creator/:id directly (no server cache).
  ref.invalidate(creatorMomentsProvider);
}
