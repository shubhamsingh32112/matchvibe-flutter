import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/moments_models.dart';
import '../services/moments_api_service.dart';

bool _momentsEnabled(Ref ref) => ref.watch(appFeaturesProvider).momentsEnabled;

class MomentsAccessState {
  const MomentsAccessState({
    required this.hasFullAccess,
    required this.showPaywall,
    required this.showPremiumUi,
    this.premiumExpiresAt,
  });

  final bool hasFullAccess;
  final bool showPaywall;
  final bool showPremiumUi;
  final DateTime? premiumExpiresAt;
}

final momentsAccessStateProvider = Provider<MomentsAccessState>((ref) {
  final features = ref.watch(appFeaturesProvider);
  final user = ref.watch(authProvider.select((s) => s.user));
  final role = user?.role;
  final isCreatorOrAdmin = role == 'creator' || role == 'admin';
  final isFreeMode = features.isMomentsFreeAccessMode;
  final isPremiumActive = user?.isMomentsPremiumActive ?? false;
  final premiumExpiresAt = user?.momentsPremiumStatus.expiresAt;

  final hasFullAccess =
      isFreeMode || isPremiumActive || isCreatorOrAdmin;
  final showPremiumUi = features.isMomentsPaidAccessMode && !isCreatorOrAdmin;
  final showPaywall = showPremiumUi && !hasFullAccess;

  return MomentsAccessState(
    hasFullAccess: hasFullAccess,
    showPaywall: showPaywall,
    showPremiumUi: showPremiumUi,
    premiumExpiresAt: premiumExpiresAt,
  );
});

/// Schedules feed refresh when Moments Premium expires.
final momentsPremiumExpiryWatcherProvider = Provider<void>((ref) {
  final expiresAt = ref.watch(
    momentsAccessStateProvider.select((s) => s.premiumExpiresAt),
  );
  if (expiresAt == null) return;

  final timer = Timer(
    expiresAt.difference(DateTime.now()),
    () {
      unawaited(ref.read(authProvider.notifier).refreshUser());
      invalidateMomentsFeeds(ref.container);
    },
  );
  ref.onDispose(timer.cancel);
});

class MomentsFeedState {
  const MomentsFeedState({
    this.items = const [],
    this.previewEndIndex = 0,
  });

  final List<MomentFeedItem> items;
  final int previewEndIndex;
}

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

int filteredPreviewEndIndex(
  List<MomentFeedItem> allItems,
  MomentsMediaFilter filter,
  int previewEndIndex,
) {
  if (previewEndIndex <= 0) return 0;
  final previewSlice = allItems.take(previewEndIndex).toList();
  return applyMediaFilter(previewSlice, filter).length;
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

class FollowingFeedNotifier extends AsyncNotifier<MomentsFeedState> {
  int _nextOffset = 0;
  bool _hasMore = true;
  bool _loadingMore = false;

  @override
  Future<MomentsFeedState> build() async {
    if (!ref.watch(appFeaturesProvider).momentsEnabled) {
      return const MomentsFeedState();
    }
    final result = await MomentsApiService().fetchFollowingFeed();
    _nextOffset = result.nextOffset;
    _hasMore = result.hasMore;
    return MomentsFeedState(
      items: result.items,
      previewEndIndex: result.sections.previewEndIndex,
    );
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
      final current = state.value ?? const MomentsFeedState();
      state = AsyncData(
        MomentsFeedState(
          items: [...current.items, ...result.items],
          previewEndIndex: current.previewEndIndex,
        ),
      );
    } finally {
      _loadingMore = false;
    }
  }

  void updateItem(int index, MomentFeedItem item) {
    final current = state.value ?? const MomentsFeedState();
    final items = [...current.items];
    if (index < 0 || index >= items.length) return;
    items[index] = item;
    state = AsyncData(
      MomentsFeedState(
        items: items,
        previewEndIndex: current.previewEndIndex,
      ),
    );
  }

  void patchFollowStateForCreator(String creatorId, bool isFollowing) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      MomentsFeedState(
        previewEndIndex: current.previewEndIndex,
        items: current.items
            .map(
              (item) => item.creatorId == creatorId
                  ? item.copyWith(isFollowing: isFollowing)
                  : item,
            )
            .toList(),
      ),
    );
  }
}

final followingFeedProvider =
    AsyncNotifierProvider<FollowingFeedNotifier, MomentsFeedState>(
  FollowingFeedNotifier.new,
);

class PopularFeedNotifier extends AsyncNotifier<MomentsFeedState> {
  String? _nextCursor;
  bool _loadingMore = false;

  @override
  Future<MomentsFeedState> build() async {
    if (!ref.watch(appFeaturesProvider).momentsEnabled) {
      return const MomentsFeedState();
    }
    final result = await MomentsApiService().fetchFeed();
    _nextCursor = result.nextCursor;
    return MomentsFeedState(
      items: result.items,
      previewEndIndex: result.sections.previewEndIndex,
    );
  }

  Future<void> loadMore() async {
    if (_loadingMore || _nextCursor == null) return;
    _loadingMore = true;
    try {
      final result = await MomentsApiService().fetchFeed(cursor: _nextCursor);
      _nextCursor = result.nextCursor;
      final current = state.value ?? const MomentsFeedState();
      state = AsyncData(
        MomentsFeedState(
          items: [...current.items, ...result.items],
          previewEndIndex: current.previewEndIndex,
        ),
      );
    } finally {
      _loadingMore = false;
    }
  }

  void updateItem(int index, MomentFeedItem item) {
    final current = state.value ?? const MomentsFeedState();
    final items = [...current.items];
    if (index < 0 || index >= items.length) return;
    items[index] = item;
    state = AsyncData(
      MomentsFeedState(
        items: items,
        previewEndIndex: current.previewEndIndex,
      ),
    );
  }

  void patchFollowStateForCreator(String creatorId, bool isFollowing) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      MomentsFeedState(
        previewEndIndex: current.previewEndIndex,
        items: current.items
            .map(
              (item) => item.creatorId == creatorId
                  ? item.copyWith(isFollowing: isFollowing)
                  : item,
            )
            .toList(),
      ),
    );
  }
}

final popularFeedProvider =
    AsyncNotifierProvider<PopularFeedNotifier, MomentsFeedState>(
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

void invalidateMomentsFeeds(ProviderContainer container) {
  container.invalidate(storiesBarProvider);
  container.invalidate(followingFeedProvider);
  container.invalidate(popularFeedProvider);
  container.invalidate(myStoriesProvider);
  container.invalidate(myMomentsProvider);
  container.invalidate(creatorMomentsAnalyticsProvider);
  container.invalidate(creatorMomentsProvider);
}
