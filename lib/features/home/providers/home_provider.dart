import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/creator_model.dart';
import '../../../shared/models/profile_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../admin/providers/admin_view_provider.dart';
import 'availability_provider.dart';
import '../../user/providers/user_availability_provider.dart';

const int homeFeedPageSize = 20;
typedef HomeApiGet = Future<dynamic> Function(String path);

final homeApiGetProvider = Provider<HomeApiGet>((_) {
  final apiClient = ApiClient();
  return apiClient.get;
});

class FeedPaginationMeta {
  final int page;
  final int limit;
  final int total;
  final bool hasMore;
  final bool isLoadingMore;

  const FeedPaginationMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.hasMore,
    required this.isLoadingMore,
  });

  const FeedPaginationMeta.initial()
    : page = 1,
      limit = homeFeedPageSize,
      total = 0,
      hasMore = true,
      isLoadingMore = false;
}

final creatorsFeedMetaProvider = StateProvider<FeedPaginationMeta>(
  (_) => const FeedPaginationMeta.initial(),
);
final usersFeedMetaProvider = StateProvider<FeedPaginationMeta>(
  (_) => const FeedPaginationMeta.initial(),
);

class _FeedPerfProbe {
  static void reorderDuration(Duration elapsed, int totalCreators) {
    if (kReleaseMode) return;
    debugPrint(
      '📈 [HOME PERF] reorder=${elapsed.inMicroseconds}us creators=$totalCreators',
    );
  }
}

class CreatorFeedNotifier extends AsyncNotifier<List<CreatorModel>> {
  int _nextPage = 1;
  int _total = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _requestId = 0;
  List<CreatorModel> _items = const [];
  List<CreatorModel>? _fallbackFullList;

  @override
  Future<List<CreatorModel>> build() async {
    return _loadInitial();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    _publishMeta();
    final localRequest = ++_requestId;
    try {
      if (_fallbackFullList != null) {
        final all = _fallbackFullList!;
        final nextLength = (_items.length + homeFeedPageSize).clamp(0, all.length);
        _items = all.take(nextLength).toList();
        _hasMore = _items.length < all.length;
        state = AsyncData(_items);
      } else {
        final page = await _fetchPage(_nextPage);
        if (localRequest != _requestId) return;
        _items = [..._items, ...page.items];
        _nextPage = page.page + 1;
        _total = page.total ?? _items.length;
        _hasMore = page.hasMore;
        state = AsyncData(_items);
      }
    } catch (e, st) {
      debugPrint('❌ [HOME] Failed to load more creators: $e');
      state = AsyncError(e, st);
    } finally {
      _isLoadingMore = false;
      _publishMeta();
    }
  }

  Future<void> refreshFeed() async {
    state = const AsyncLoading<List<CreatorModel>>().copyWithPrevious(state);
    state = await AsyncValue.guard(_loadInitial);
  }

  Future<List<CreatorModel>> _loadInitial() async {
    _nextPage = 1;
    _total = 0;
    _hasMore = true;
    _isLoadingMore = false;
    _fallbackFullList = null;
    _publishMeta();
    final page = await _fetchPage(1);
    _items = page.items;
    _nextPage = page.page + 1;
    _total = page.total ?? _items.length;
    _hasMore = page.hasMore;
    _publishMeta();
    return _items;
  }

  Future<_CreatorPage> _fetchPage(int page) async {
    final response = await ref.read(homeApiGetProvider)(
      '/creator?page=$page&limit=$homeFeedPageSize',
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch creators: status ${response.statusCode}');
    }
    final responseData = response.data;
    if (responseData['success'] != true || responseData['data'] == null) {
      return const _CreatorPage(items: [], page: 1, hasMore: false);
    }
    final creatorsData = responseData['data']['creators'] as List? ?? const [];
    final creators = creatorsData
        .map((json) => CreatorModel.fromJson(json as Map<String, dynamic>))
        .toList();

    final apiAvailability = <String, CreatorAvailability>{};
    for (final creator in creators) {
      if (creator.firebaseUid != null) {
        apiAvailability[creator.firebaseUid!] = creator.availability == 'online'
            ? CreatorAvailability.online
            : CreatorAvailability.busy;
      }
    }
    ref.read(creatorAvailabilityProvider.notifier).seedFromApi(apiAvailability);

    final pagination =
        responseData['data']['pagination'] as Map<String, dynamic>?;
    if (pagination != null) {
      final currentPage = (pagination['page'] as num?)?.toInt() ?? page;
      final total = (pagination['total'] as num?)?.toInt();
      final totalPages = (pagination['totalPages'] as num?)?.toInt() ?? currentPage;
      return _CreatorPage(
        items: creators,
        page: currentPage,
        total: total,
        hasMore: currentPage < totalPages,
      );
    }

    // Backward-compatible fallback for backends that still return full catalog.
    _fallbackFullList = creators;
    final firstPage = creators.take(homeFeedPageSize).toList();
    return _CreatorPage(
      items: firstPage,
      page: 1,
      total: creators.length,
      hasMore: creators.length > firstPage.length,
    );
  }

  void _publishMeta() {
    Future<void>.microtask(() {
      ref.read(creatorsFeedMetaProvider.notifier).state = FeedPaginationMeta(
        page: _nextPage <= 1 ? 1 : _nextPage - 1,
        limit: homeFeedPageSize,
        total: _total,
        hasMore: _hasMore,
        isLoadingMore: _isLoadingMore,
      );
    });
  }
}

class UserFeedNotifier extends AsyncNotifier<List<UserProfileModel>> {
  int _nextPage = 1;
  int _total = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _requestId = 0;
  List<UserProfileModel> _items = const [];

  @override
  Future<List<UserProfileModel>> build() async {
    return _loadInitial();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    _publishMeta();
    final localRequest = ++_requestId;
    try {
      final page = await _fetchPage(_nextPage);
      if (localRequest != _requestId) return;
      _items = [..._items, ...page.items];
      _nextPage = page.page + 1;
      _total = page.total ?? _items.length;
      _hasMore = page.hasMore;
      state = AsyncData(_items);
    } catch (e, st) {
      debugPrint('❌ [HOME] Failed to load more users: $e');
      state = AsyncError(e, st);
    } finally {
      _isLoadingMore = false;
      _publishMeta();
    }
  }

  Future<void> refreshFeed() async {
    state = const AsyncLoading<List<UserProfileModel>>().copyWithPrevious(state);
    state = await AsyncValue.guard(_loadInitial);
  }

  Future<List<UserProfileModel>> _loadInitial() async {
    _nextPage = 1;
    _total = 0;
    _hasMore = true;
    _isLoadingMore = false;
    _publishMeta();
    final page = await _fetchPage(1);
    _items = page.items;
    _nextPage = page.page + 1;
    _total = page.total ?? _items.length;
    _hasMore = page.hasMore;
    _publishMeta();
    return _items;
  }

  Future<_UserPage> _fetchPage(int page) async {
    final response = await ref.read(homeApiGetProvider)(
      '/user/list?page=$page&limit=$homeFeedPageSize',
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch users: status ${response.statusCode}');
    }
    final usersData = response.data['data']['users'] as List? ?? const [];
    final users = usersData
        .map((json) => UserProfileModel.fromJson(json as Map<String, dynamic>))
        .toList();
    final pagination = response.data['data']['pagination'] as Map<String, dynamic>?;

    final apiAvailability = <String, UserAvailability>{};
    for (final user in users) {
      if (user.firebaseUid != null) {
        apiAvailability[user.firebaseUid!] = user.availability == 'online'
            ? UserAvailability.online
            : UserAvailability.offline;
      }
    }
    ref.read(userAvailabilityProvider.notifier).seedFromApi(apiAvailability);

    final currentPage = (pagination?['page'] as num?)?.toInt() ?? page;
    final total = (pagination?['total'] as num?)?.toInt();
    final totalPages = (pagination?['totalPages'] as num?)?.toInt() ?? currentPage;
    return _UserPage(
      items: users,
      page: currentPage,
      total: total,
      hasMore: currentPage < totalPages,
    );
  }

  void _publishMeta() {
    Future<void>.microtask(() {
      ref.read(usersFeedMetaProvider.notifier).state = FeedPaginationMeta(
        page: _nextPage <= 1 ? 1 : _nextPage - 1,
        limit: homeFeedPageSize,
        total: _total,
        hasMore: _hasMore,
        isLoadingMore: _isLoadingMore,
      );
    });
  }
}

final creatorsProvider =
    AsyncNotifierProvider<CreatorFeedNotifier, List<CreatorModel>>(
      CreatorFeedNotifier.new,
    );

// Provider to fetch creators (for users)
// Provider to fetch users (for creators)
final usersProvider =
    AsyncNotifierProvider<UserFeedNotifier, List<UserProfileModel>>(
      UserFeedNotifier.new,
    );

class CreatorOrderState {
  final List<String> orderedIds;
  const CreatorOrderState({required this.orderedIds});
}

class CreatorOrderNotifier extends StateNotifier<CreatorOrderState> {
  CreatorOrderNotifier() : super(const CreatorOrderState(orderedIds: []));

  final Map<String, double> _scoreById = <String, double>{};
  final Map<String, CreatorAvailability> _statusById =
      <String, CreatorAvailability>{};
  final List<String> _onlineIds = <String>[];
  final List<String> _busyIds = <String>[];
  String? _lastUserId;
  String _lastCreatorFingerprint = '';

  void syncCreators(
    List<CreatorModel> creators,
    Map<String, CreatorAvailability> availabilityMap,
    String userId,
  ) {
    final creatorFingerprint = _buildCreatorFingerprint(creators);
    final shouldRebuild =
        userId != _lastUserId || creatorFingerprint != _lastCreatorFingerprint;
    if (!shouldRebuild) return;

    _scoreById.clear();
    _statusById.clear();
    _onlineIds.clear();
    _busyIds.clear();

    for (final creator in creators) {
      final firebaseUid = creator.firebaseUid;
      if (firebaseUid == null || firebaseUid.isEmpty) continue;
      final score = _stableScore(userId, firebaseUid);
      _scoreById[firebaseUid] = score;
      final availability =
          availabilityMap[firebaseUid] ??
          (creator.availability == 'online'
              ? CreatorAvailability.online
              : CreatorAvailability.busy);
      _statusById[firebaseUid] = availability;
      if (availability == CreatorAvailability.online) {
        _onlineIds.add(firebaseUid);
      } else {
        _busyIds.add(firebaseUid);
      }
    }

    _onlineIds.sort(_sortByScore);
    _busyIds.sort(_sortByScore);
    _lastUserId = userId;
    _lastCreatorFingerprint = creatorFingerprint;
    _emit();
  }

  void updateBatch(Map<String, CreatorAvailability> updates) {
    if (updates.isEmpty || _scoreById.isEmpty) return;
    var changed = false;
    for (final entry in updates.entries) {
      final id = entry.key;
      if (!_scoreById.containsKey(id)) continue;
      final nextStatus = entry.value;
      final previous = _statusById[id];
      if (previous == nextStatus) continue;
      _statusById[id] = nextStatus;
      _onlineIds.remove(id);
      _busyIds.remove(id);
      if (nextStatus == CreatorAvailability.online) {
        _insertSorted(_onlineIds, id);
      } else {
        _insertSorted(_busyIds, id);
      }
      changed = true;
    }
    if (changed) _emit();
  }

  List<CreatorModel> resolveOrdered(List<CreatorModel> creators) {
    if (state.orderedIds.isEmpty) return creators;
    final byId = <String, CreatorModel>{};
    final missing = <CreatorModel>[];
    for (final creator in creators) {
      final id = creator.firebaseUid;
      if (id == null || id.isEmpty) {
        missing.add(creator);
      } else {
        byId[id] = creator;
      }
    }
    final ordered = <CreatorModel>[];
    for (final id in state.orderedIds) {
      final creator = byId.remove(id);
      if (creator != null) ordered.add(creator);
    }
    ordered.addAll(byId.values);
    ordered.addAll(missing);
    return ordered;
  }

  int _sortByScore(String a, String b) =>
      (_scoreById[a] ?? 0).compareTo(_scoreById[b] ?? 0);

  void _insertSorted(List<String> list, String id) {
    final idScore = _scoreById[id] ?? 0;
    var low = 0;
    var high = list.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      final midScore = _scoreById[list[mid]] ?? 0;
      if (midScore <= idScore) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    list.insert(low, id);
  }

  double _stableScore(String userId, String creatorId) {
    final hash = Object.hash(userId, creatorId) & 0x7fffffff;
    return hash / 0x7fffffff;
  }

  String _buildCreatorFingerprint(List<CreatorModel> creators) {
    final ids = creators
        .map((creator) => creator.firebaseUid)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList()
      ..sort();
    return ids.join('|');
  }

  void _emit() {
    final ordered = [..._onlineIds, ..._busyIds];
    state = CreatorOrderState(orderedIds: ordered);
  }
}

final creatorOrderProvider =
    StateNotifierProvider<CreatorOrderNotifier, CreatorOrderState>(
      (_) => CreatorOrderNotifier(),
    );

final creatorOrderBridgeProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<CreatorModel>>>(creatorsProvider, (prev, next) {
    next.whenData((creators) {
      final userId = ref.read(authProvider).user?.id;
      if (userId == null) return;
      final availability = ref.read(creatorAvailabilityProvider);
      ref
          .read(creatorOrderProvider.notifier)
          .syncCreators(creators, availability, userId);
    });
  });

  ref.listen<Map<String, CreatorAvailability>>(
    creatorAvailabilityProvider,
    (prev, next) {
      if (prev == null) {
        ref.read(creatorOrderProvider.notifier).updateBatch(next);
        return;
      }
      final updates = <String, CreatorAvailability>{};
      for (final entry in next.entries) {
        final previous = prev[entry.key];
        if (previous != entry.value) {
          updates[entry.key] = entry.value;
        }
      }
      if (updates.isNotEmpty) {
        ref.read(creatorOrderProvider.notifier).updateBatch(updates);
      }
    },
  );
});

/// 🔥 BACKEND-AUTHORITATIVE Provider that returns ALL creators/users based on user role
final homeFeedProvider = Provider<List<dynamic>>((ref) {
  ref.watch(creatorOrderBridgeProvider);

  final authState = ref.watch(authProvider);
  final user = authState.user;

  if (user == null) {
    return [];
  }

  // If user is an admin, check their view mode preference
  if (user.role == 'admin') {
    final adminViewMode = ref.watch(adminViewModeProvider);
    final creatorsAsync = ref.watch(creatorsProvider);

    // Default to user view if not set
    if (adminViewMode == null || adminViewMode == AdminViewMode.user) {
      final orderState = ref.watch(creatorOrderProvider);
      return creatorsAsync.when(
        data: (creators) {
          final stopwatch = Stopwatch()..start();
          final ordered = ref
              .read(creatorOrderProvider.notifier)
              .resolveOrdered(creators);
          stopwatch.stop();
          _FeedPerfProbe.reorderDuration(stopwatch.elapsed, creators.length);
          if (orderState.orderedIds.isEmpty) return creators;
          return ordered;
        },
        loading: () => [],
        error: (_, __) => [],
      );
    } else {
      // Admin viewing as creator: show users
      final usersAsync = ref.watch(usersProvider);
      return usersAsync.when(
        data: (users) => users,
        loading: () => [],
        error: (_, __) => [],
      );
    }
  }

  // If user is a creator, show users
  if (user.role == 'creator') {
    final usersAsync = ref.watch(usersProvider);
    return usersAsync.when(
      data: (users) => users,
      loading: () => [],
      error: (_, __) => [],
    );
  }

  // If user is a regular user, show ALL creators.
  // Availability (online/busy) is managed via Socket.IO + Redis in real-time.
  final creatorsAsync = ref.watch(creatorsProvider);
  final orderState = ref.watch(creatorOrderProvider);

  return creatorsAsync.when(
    data: (creators) {
      final stopwatch = Stopwatch()..start();
      final ordered = ref.read(creatorOrderProvider.notifier).resolveOrdered(creators);
      stopwatch.stop();
      _FeedPerfProbe.reorderDuration(stopwatch.elapsed, creators.length);

      debugPrint(
        '✅ [HOME] Returning ${ordered.length} creator(s), orderedIds=${orderState.orderedIds.length}',
      );
      if (orderState.orderedIds.isEmpty) return creators;
      return ordered;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

final homeFeedHasMoreProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) return false;
  if (user.role == 'creator' ||
      (user.role == 'admin' &&
          ref.watch(adminViewModeProvider) == AdminViewMode.creator)) {
    return ref.watch(usersFeedMetaProvider).hasMore;
  }
  return ref.watch(creatorsFeedMetaProvider).hasMore;
});

class _CreatorPage {
  final List<CreatorModel> items;
  final int page;
  final int? total;
  final bool hasMore;

  const _CreatorPage({
    required this.items,
    required this.page,
    this.total,
    required this.hasMore,
  });
}

class _UserPage {
  final List<UserProfileModel> items;
  final int page;
  final int? total;
  final bool hasMore;

  const _UserPage({
    required this.items,
    required this.page,
    this.total,
    required this.hasMore,
  });
}
