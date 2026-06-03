import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/sentry_service.dart';
import '../../../shared/models/creator_model.dart';
import '../../../shared/models/profile_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../admin/providers/admin_view_provider.dart';
import 'availability_provider.dart';
import '../services/home_feed_metrics.dart';
import '../../user/providers/user_availability_provider.dart';

const int homeFeedPageSize = 20;

/// Max creators inserted via socket (not from paginated feed) to bound memory.
const int maxSocketInsertedCreators = 200;
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

bool creatorFeedAuthReady(AuthState auth) {
  if (auth.user == null) return false;
  final role = auth.user!.role;
  if (role == 'creator') return false;
  return true;
}

@visibleForTesting
bool creatorFeedAuthReadyForAdmin(AuthState auth, AdminViewMode? viewMode) {
  if (auth.user == null) return false;
  if (auth.user!.role != 'admin') return creatorFeedAuthReady(auth);
  return viewMode == null || viewMode == AdminViewMode.user;
}

class _FeedPerfProbe {
  static void reorderDuration(Duration elapsed, int totalCreators) {
    if (kReleaseMode) return;
    debugPrint(
      '📈 [HOME PERF] reorder=${elapsed.inMicroseconds}us creators=$totalCreators',
    );
  }
}

String? _normalizeFirebaseUid(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

CreatorAvailability resolveCreatorAvailabilityForFeed(
  CreatorModel creator,
  Map<String, CreatorAvailability> availabilityMap,
) {
  final uid = _normalizeFirebaseUid(creator.firebaseUid);
  if (uid != null && availabilityMap.containsKey(uid)) {
    return availabilityMap[uid]!;
  }
  return creator.availability == 'online'
      ? CreatorAvailability.online
      : creator.availability == 'on_call'
      ? CreatorAvailability.onCall
      : CreatorAvailability.offline;
}

class CreatorFeedNotifier extends AsyncNotifier<List<CreatorModel>> {
  int _nextPage = 1;
  int _total = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _requestId = 0;
  List<CreatorModel> _items = const [];
  final Set<String> _socketInsertedFirebaseUids = <String>{};
  final Set<String> _insertInFlightByFirebaseUid = <String>{};

  bool _shouldFetchCreators(AuthState auth) {
    if (auth.user == null) return false;
    final role = auth.user!.role;
    if (role == 'creator') return false;
    if (role == 'admin') {
      final viewMode = ref.read(adminViewModeProvider);
      return creatorFeedAuthReadyForAdmin(auth, viewMode);
    }
    return true;
  }

  @override
  Future<List<CreatorModel>> build() async {
    final auth = ref.read(authProvider);
    ref.listen<AuthState>(authProvider, (previous, next) {
      final prevUid = previous?.firebaseUser?.uid;
      final nextUid = next.firebaseUser?.uid;
      final prevRole = previous?.user?.role;
      final nextRole = next.user?.role;
      final userBecameReady = previous?.user == null && next.user != null;
      final roleChanged = prevRole != nextRole;
      if (_shouldFetchCreators(next) &&
          (userBecameReady || prevUid != nextUid || roleChanged)) {
        unawaited(refreshFeed());
      }
    });
    if (!_shouldFetchCreators(auth)) {
      return const [];
    }
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
    _socketInsertedFirebaseUids.clear();
    _insertInFlightByFirebaseUid.clear();
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
    final txn = SentryService.startTransaction('home.feed_load', 'ui.load');
    try {
      final response = await ref.read(homeApiGetProvider)(
        '/creator/feed?page=$page&limit=$homeFeedPageSize&sort=availability',
      );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch creators: status ${response.statusCode}');
    }
    final responseData = response.data;
    if (responseData is! Map<String, dynamic>) {
      throw Exception('Invalid creators feed response');
    }
    if (responseData['success'] != true || responseData['data'] == null) {
      final serverError = responseData['error']?.toString();
      throw Exception(
        serverError?.isNotEmpty == true
            ? serverError!
            : 'Failed to fetch creators',
      );
    }
    final creatorsData = responseData['data']['creators'] as List? ?? const [];
    final creators = <CreatorModel>[];
    for (final raw in creatorsData) {
      if (raw is! Map) continue;
      try {
        creators.add(
          CreatorModel.fromJson(Map<String, dynamic>.from(raw)),
        );
      } catch (e, st) {
        debugPrint('⚠️ [HOME] Skipping malformed creator row: $e');
        debugPrint('$st');
      }
    }
    if (creatorsData.isNotEmpty && creators.isEmpty) {
      throw Exception(
        'CREATOR_FEED_PARSE_FAILED: server returned ${creatorsData.length} row(s) '
        'but none could be parsed (check API / app versions).',
      );
    }

    final apiAvailability = <String, CreatorAvailability>{};
    for (final creator in creators) {
      final uid = _normalizeFirebaseUid(creator.firebaseUid);
      if (uid != null) {
        apiAvailability[uid] = creator.availability == 'online'
            ? CreatorAvailability.online
            : creator.availability == 'on_call'
            ? CreatorAvailability.onCall
            : CreatorAvailability.offline;
      }
    }
    ref.read(creatorAvailabilityProvider.notifier).seedFromApi(apiAvailability);

    final liveUids = apiAvailability.keys.toList(growable: false);
    if (liveUids.isNotEmpty) {
      ref.read(socketServiceProvider).requestAvailability(liveUids);
    }

    final pagination =
        responseData['data']['pagination'] as Map<String, dynamic>?;
    if (pagination == null) {
      return _CreatorPage(
        items: creators,
        page: page,
        total: creators.length,
        hasMore: false,
      );
    }
    final currentPage = (pagination['page'] as num?)?.toInt() ?? page;
    final total = (pagination['total'] as num?)?.toInt();
    final totalPages = (pagination['totalPages'] as num?)?.toInt() ?? currentPage;
    return _CreatorPage(
      items: creators,
      page: currentPage,
      total: total,
      hasMore: currentPage < totalPages,
    );
    } finally {
      await txn.finish();
    }
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

  /// Lifecycle for socket-driven rows: remove socket-inserted creators when they go offline.
  void handlePresenceTransitionForFeed({
    required String firebaseUid,
    required String status,
  }) {
    if (!_shouldFetchCreators(ref.read(authProvider))) return;
    final uid = _normalizeFirebaseUid(firebaseUid);
    if (uid == null) return;

    if (status != 'offline') return;
    if (!_socketInsertedFirebaseUids.contains(uid)) return;

    _socketInsertedFirebaseUids.remove(uid);
    _items = _items.where((c) => _normalizeFirebaseUid(c.firebaseUid) != uid).toList(
      growable: false,
    );
    state = AsyncData(_items);

    final userId = ref.read(authProvider).user?.id;
    if (userId != null) {
      final availability = ref.read(creatorAvailabilityProvider);
      ref
          .read(creatorOrderProvider.notifier)
          .syncCreators(_items, availability, userId, force: true);
    }
  }

  /// Socket-driven discovery: insert a newly-online creator without loading the full catalog.
  void insertOrUpdateFromStatusEvent({
    required String firebaseUid,
    required String status,
    Map<String, dynamic>? creatorSummary,
  }) {
    if (!_shouldFetchCreators(ref.read(authProvider))) return;
    final uid = _normalizeFirebaseUid(firebaseUid);
    if (uid == null) return;

    if (status != 'online') return;

    if (_hasCreatorInFeed(uid)) return;
    if (_insertInFlightByFirebaseUid.contains(uid)) return;

    if (creatorSummary != null) {
      _insertInFlightByFirebaseUid.add(uid);
      try {
        final model = CreatorModel.fromJson(
          Map<String, dynamic>.from(creatorSummary),
        );
        _insertCreatorFromSocket(model, uid);
      } catch (e, st) {
        debugPrint('⚠️ [HOME] creatorSummary parse failed for $uid: $e');
        debugPrint('$st');
        unawaited(ensureCreatorInFeedByFirebaseUid(uid));
      } finally {
        _insertInFlightByFirebaseUid.remove(uid);
      }
      return;
    }

    unawaited(ensureCreatorInFeedByFirebaseUid(uid));
  }

  Future<void> ensureCreatorInFeedByFirebaseUid(String firebaseUid) async {
    if (!_shouldFetchCreators(ref.read(authProvider))) return;
    final uid = _normalizeFirebaseUid(firebaseUid);
    if (uid == null) return;
    if (_hasCreatorInFeed(uid)) return;
    if (_insertInFlightByFirebaseUid.contains(uid)) return;

    _insertInFlightByFirebaseUid.add(uid);
    var fetchOk = false;
    try {
      final response = await ref.read(homeApiGetProvider)(
        '/creator/by-firebase-uid/$uid',
      );
      if (response.statusCode != 200) return;
      final body = response.data as Map<String, dynamic>?;
      if (body?['success'] != true || body?['data'] == null) return;
      final raw = (body!['data'] as Map<String, dynamic>)['creator'];
      if (raw is! Map) return;
      final model = CreatorModel.fromJson(Map<String, dynamic>.from(raw));
      fetchOk = true;
      if (model.availability != 'online') return;
      _insertCreatorFromSocket(model, uid);
    } catch (e) {
      debugPrint('⚠️ [HOME] ensureCreatorInFeed failed for $uid: $e');
    } finally {
      HomeFeedMetrics.recordByUidFetch(success: fetchOk);
      _insertInFlightByFirebaseUid.remove(uid);
    }
  }

  bool _hasCreatorInFeed(String firebaseUid) {
    return _items.any((c) => _normalizeFirebaseUid(c.firebaseUid) == firebaseUid);
  }

  List<CreatorModel> _dedupeItemsByFirebaseUid(List<CreatorModel> items) {
    final seen = <String>{};
    final deduped = <CreatorModel>[];
    var dropped = 0;
    for (final creator in items) {
      final uid = _normalizeFirebaseUid(creator.firebaseUid);
      if (uid == null) {
        deduped.add(creator);
        continue;
      }
      if (seen.contains(uid)) {
        dropped++;
        continue;
      }
      seen.add(uid);
      deduped.add(creator);
    }
    if (dropped > 0) {
      HomeFeedMetrics.recordSocketInsertionDeduplicated(dropped);
    }
    return deduped;
  }

  void _insertCreatorFromSocket(CreatorModel model, String firebaseUid) {
    final uid = _normalizeFirebaseUid(firebaseUid);
    if (uid == null) return;
    if (_hasCreatorInFeed(uid)) return;

    _enforceSocketInsertCap();
    _socketInsertedFirebaseUids.add(uid);
    _items = _dedupeItemsByFirebaseUid([model, ..._items]);
    state = AsyncData(_items);
    HomeFeedMetrics.recordSocketInsertion();

    final apiAvailability = <String, CreatorAvailability>{
      uid: CreatorAvailability.online,
    };
    ref.read(creatorAvailabilityProvider.notifier).seedFromApi(apiAvailability);
    ref.read(socketServiceProvider).requestAvailability([uid]);

    final userId = ref.read(authProvider).user?.id;
    if (userId != null) {
      final availability = ref.read(creatorAvailabilityProvider);
      ref
          .read(creatorOrderProvider.notifier)
          .syncCreators(_items, availability, userId, force: true);
    }
  }

  void _enforceSocketInsertCap() {
    while (_socketInsertedFirebaseUids.length >= maxSocketInsertedCreators) {
      final evictUid = _socketInsertedFirebaseUids.first;
      _socketInsertedFirebaseUids.remove(evictUid);
      _items = _items
          .where((c) => _normalizeFirebaseUid(c.firebaseUid) != evictUid)
          .toList(growable: false);
      HomeFeedMetrics.recordSocketInsertionRejectedCap();
    }
  }

  @visibleForTesting
  Set<String> socketInsertedFirebaseUidsForTest() =>
      Set<String>.unmodifiable(_socketInsertedFirebaseUids);

  @visibleForTesting
  List<CreatorModel> feedItemsForTest() => List<CreatorModel>.unmodifiable(_items);

  @visibleForTesting
  void debugSeedFeedState({
    required List<CreatorModel> items,
    Set<String>? socketInsertedUids,
  }) {
    _items = List<CreatorModel>.from(items);
    if (socketInsertedUids != null) {
      _socketInsertedFirebaseUids
        ..clear()
        ..addAll(socketInsertedUids);
    }
    state = AsyncData(_items);
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
    final users = <UserProfileModel>[];
    for (final raw in usersData) {
      if (raw is! Map) continue;
      try {
        users.add(UserProfileModel.fromJson(Map<String, dynamic>.from(raw)));
      } catch (e, st) {
        debugPrint('⚠️ [HOME] Skipping malformed user row: $e');
        debugPrint('$st');
      }
    }
    if (usersData.isNotEmpty && users.isEmpty) {
      throw Exception(
        'USER_FEED_PARSE_FAILED: server returned ${usersData.length} row(s) '
        'but none could be parsed (check API / app versions).',
      );
    }
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

/// Full creator profile (gallery, about) for progressive hydration after feed cards.
final creatorDetailProvider =
    FutureProvider.autoDispose.family<CreatorModel, String>((ref, creatorId) async {
  final response = await ref.read(homeApiGetProvider)('/creator/$creatorId');
  if (response.statusCode != 200) {
    throw Exception(
      'Failed to fetch creator detail: status ${response.statusCode}',
    );
  }
  final responseData = response.data as Map<String, dynamic>?;
  if (responseData?['success'] != true || responseData?['data'] == null) {
    throw Exception('Invalid creator detail response');
  }
  final data = responseData!['data'] as Map<String, dynamic>;
  final raw = data['creator'];
  if (raw is! Map) {
    throw Exception('Missing creator in response');
  }
  return CreatorModel.fromJson(Map<String, dynamic>.from(raw));
});

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
  final List<String> _unavailableIds = <String>[];
  String? _lastUserId;
  String _lastCreatorFingerprint = '';

  void syncCreators(
    List<CreatorModel> creators,
    Map<String, CreatorAvailability> availabilityMap,
    String userId, {
    bool force = false,
  }) {
    final creatorFingerprint = _buildCreatorFingerprint(creators);
    final shouldRebuild = force ||
        userId != _lastUserId ||
        creatorFingerprint != _lastCreatorFingerprint;
    if (!shouldRebuild) return;

    _scoreById.clear();
    _statusById.clear();
    _onlineIds.clear();
    _unavailableIds.clear();

    for (final creator in creators) {
      final firebaseUid = creator.firebaseUid;
      if (firebaseUid == null || firebaseUid.isEmpty) continue;
      final score = _stableScore(userId, firebaseUid);
      _scoreById[firebaseUid] = score;
      final availability = resolveCreatorAvailabilityForFeed(
        creator,
        availabilityMap,
      );
      _statusById[firebaseUid] = availability;
      if (availability == CreatorAvailability.online) {
        _onlineIds.add(firebaseUid);
      } else {
        _unavailableIds.add(firebaseUid);
      }
    }

    _onlineIds.sort(_sortByScore);
    _unavailableIds.sort(_sortByScore);
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
      _unavailableIds.remove(id);
      if (nextStatus == CreatorAvailability.online) {
        _insertSorted(_onlineIds, id);
      } else {
        _insertSorted(_unavailableIds, id);
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
    final ordered = [..._onlineIds, ..._unavailableIds];
    state = CreatorOrderState(orderedIds: ordered);
  }
}

final creatorOrderProvider =
    StateNotifierProvider<CreatorOrderNotifier, CreatorOrderState>(
      (_) => CreatorOrderNotifier(),
    );

/// Rebuilds online-first order from the cached feed + live availability map.
void syncUserHomeFeedOrderFromCurrentFeed(Ref ref, {bool force = true}) {
  final creators = ref.read(creatorsProvider).valueOrNull;
  final userId = ref.read(authProvider).user?.id;
  if (creators == null || userId == null) return;
  ref.read(creatorOrderProvider.notifier).syncCreators(
    creators,
    ref.read(creatorAvailabilityProvider),
    userId,
    force: force,
  );
}

class _UserHomePresenceSyncGate {
  bool inFlight = false;
  DateTime? lastAt;
}

final _userHomePresenceSyncGate = _UserHomePresenceSyncGate();

/// Re-request Redis-backed presence for loaded feed creators and resync grid order.
Future<void> resyncUserHomeFeedPresenceAndOrder(
  WidgetRef ref, {
  required String reason,
  bool bypassThrottle = false,
}) async {
  final role = ref.read(authProvider).user?.role;
  if (role == 'creator') return;
  if (role == 'admin') {
    final adminViewMode = ref.read(adminViewModeProvider);
    if (adminViewMode == AdminViewMode.creator) return;
  } else if (role != 'user') {
    return;
  }

  final now = DateTime.now();
  final last = _userHomePresenceSyncGate.lastAt;
  if (!bypassThrottle &&
      last != null &&
      now.difference(last) < const Duration(seconds: 3)) {
    return;
  }
  if (_userHomePresenceSyncGate.inFlight) return;

  _userHomePresenceSyncGate.inFlight = true;
  _userHomePresenceSyncGate.lastAt = now;
  try {
    var visibleIds =
        (ref.read(creatorsProvider).valueOrNull ?? const <CreatorModel>[])
            .map((creator) => _normalizeFirebaseUid(creator.firebaseUid))
            .whereType<String>()
            .toList(growable: false);

    if (visibleIds.isEmpty) {
      final creators = await ref.read(creatorsProvider.future);
      visibleIds = creators
          .map((creator) => _normalizeFirebaseUid(creator.firebaseUid))
          .whereType<String>()
          .toList(growable: false);
    }

    if (visibleIds.isNotEmpty) {
      ref.read(socketServiceProvider).requestAvailability(visibleIds);
    }

    final creators = ref.read(creatorsProvider).valueOrNull;
    final userId = ref.read(authProvider).user?.id;
    if (creators != null && userId != null) {
      ref.read(creatorOrderProvider.notifier).syncCreators(
        creators,
        ref.read(creatorAvailabilityProvider),
        userId,
        force: true,
      );
    }

    if (!kReleaseMode) {
      debugPrint(
        '📡 [HOME] User-home creator presence rehydrated (reason=$reason)',
      );
    }
  } catch (e) {
    debugPrint(
      '⚠️ [HOME] User-home presence rehydrate failed (reason=$reason): $e',
    );
  } finally {
    _userHomePresenceSyncGate.inFlight = false;
  }
}

/// Keeps fan home presence live: tracks feed UIDs on socket, hydrates on connect/reconnect.
/// Chains [creator:status] after availability wiring to insert newly-online creators into the feed.
final creatorFeedSocketBridgeProvider = Provider<void>((ref) {
  final service = ref.read(socketServiceProvider);
  final previous = service.onCreatorStatusV2;
  service.onCreatorStatusV2 =
      (
        creatorId,
        status, {
        int? version,
        int? updatedAt,
        Map<String, dynamic>? creatorSummary,
      }) {
        HomeFeedMetrics.recordStatusEventReceived();
        previous?.call(
          creatorId,
          status,
          version: version,
          updatedAt: updatedAt,
          creatorSummary: creatorSummary,
        );
        ref.read(creatorsProvider.notifier).handlePresenceTransitionForFeed(
          firebaseUid: creatorId,
          status: status,
        );
        if (status == 'online') {
          ref.read(creatorsProvider.notifier).insertOrUpdateFromStatusEvent(
                firebaseUid: creatorId,
                status: status,
                creatorSummary: creatorSummary,
              );
        }
      };
  ref.onDispose(() {
    service.onCreatorStatusV2 = previous;
  });
});

final creatorPresenceBackboneProvider = Provider<void>((ref) {
  final service = ref.read(socketServiceProvider);

  void hydrateLoadedFeedCreators(String reason) {
    final user = ref.read(authProvider).user;
    if (user == null || user.role != 'user') return;

    final uids = (ref.read(creatorsProvider).valueOrNull ?? const <CreatorModel>[])
        .map((c) => _normalizeFirebaseUid(c.firebaseUid))
        .whereType<String>()
        .toList(growable: false);
    if (uids.isEmpty) return;
    if (!kReleaseMode) {
      debugPrint(
        '📡 [PRESENCE BACKBONE] Hydrating ${uids.length} feed creator(s) ($reason)',
      );
    }
    service.requestAvailability(uids);
  }

  final previousOnConnected = service.onConnected;
  final previousOnReconnected = service.onReconnected;
  service.onConnected = () {
    previousOnConnected?.call();
    hydrateLoadedFeedCreators('socket_connected');
  };
  service.onReconnected = () {
    previousOnReconnected?.call();
    hydrateLoadedFeedCreators('socket_reconnected');
  };

  ref.listen<AsyncValue<List<CreatorModel>>>(creatorsProvider, (prev, next) {
    next.whenData((creators) {
      final uids = creators
          .map((c) => _normalizeFirebaseUid(c.firebaseUid))
          .whereType<String>()
          .toList(growable: false);
      if (uids.isEmpty) return;
      service.requestAvailability(uids);
    });
  });

  ref.onDispose(() {
    service.onConnected = previousOnConnected;
    service.onReconnected = previousOnReconnected;
  });
});

final creatorOrderBridgeProvider = Provider<void>((ref) {
  ref.watch(creatorFeedSocketBridgeProvider);
  ref.watch(creatorPresenceBackboneProvider);

  void onAvailabilityMapChanged(
    Map<String, CreatorAvailability>? prev,
    Map<String, CreatorAvailability> next,
  ) {
    if (prev == null) {
      syncUserHomeFeedOrderFromCurrentFeed(ref, force: true);
      return;
    }
    final updates = <String, CreatorAvailability>{};
    for (final entry in next.entries) {
      final previous = prev[entry.key];
      if (previous != entry.value) {
        updates[entry.key] = entry.value;
      }
    }
    if (updates.isEmpty) return;

    final orderNotifier = ref.read(creatorOrderProvider.notifier);
    orderNotifier.updateBatch(updates);

    final creators = ref.read(creatorsProvider).valueOrNull;
    final userId = ref.read(authProvider).user?.id;
    if (creators == null || userId == null) return;

    final orderedIds = ref.read(creatorOrderProvider).orderedIds;
    final needsResync = orderedIds.isEmpty ||
        updates.keys.any((id) => !orderedIds.contains(id));
    if (needsResync) {
      orderNotifier.syncCreators(creators, next, userId, force: true);
    }

    final loadedUids = creators
        .map((c) => _normalizeFirebaseUid(c.firebaseUid))
        .whereType<String>()
        .toSet();
    for (final entry in updates.entries) {
      if (entry.value != CreatorAvailability.online) continue;
      if (loadedUids.contains(entry.key)) continue;
      unawaited(
        ref
            .read(creatorsProvider.notifier)
            .ensureCreatorInFeedByFirebaseUid(entry.key),
      );
    }
  }

  ref.listen<AsyncValue<List<CreatorModel>>>(
    creatorsProvider,
    (prev, next) {
      next.whenData((creators) {
        final userId = ref.read(authProvider).user?.id;
        if (userId == null) return;
        final availability = ref.read(creatorAvailabilityProvider);
        ref
            .read(creatorOrderProvider.notifier)
            .syncCreators(creators, availability, userId);
      });
    },
    fireImmediately: true,
  );

  ref.listen<Map<String, CreatorAvailability>>(
    creatorAvailabilityProvider,
    onAvailabilityMapChanged,
    fireImmediately: true,
  );

  syncUserHomeFeedOrderFromCurrentFeed(ref, force: true);
});

/// 🔥 BACKEND-AUTHORITATIVE Provider that returns ALL creators/users based on user role
final homeFeedProvider = Provider<List<dynamic>>((ref) {
  ref.watch(creatorFeedSocketBridgeProvider);
  ref.watch(creatorOrderBridgeProvider);

  final authIdentity = ref.watch(
    authProvider.select((s) => (s.user?.id, s.user?.role)),
  );
  final userId = authIdentity.$1;
  final userRole = authIdentity.$2;

  if (userId == null || userRole == null) {
    return [];
  }

  // If user is an admin, check their view mode preference
  if (userRole == 'admin') {
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
  if (userRole == 'creator') {
    final usersAsync = ref.watch(usersProvider);
    return usersAsync.when(
      data: (users) => users,
      loading: () => [],
      error: (_, __) => [],
    );
  }

  // If user is a regular user, show ALL creators.
  // Availability (online/on_call/offline) is managed via Socket.IO + Redis in real-time.
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
  final userRole = ref.watch(authProvider.select((s) => s.user?.role));
  if (userRole == null) return false;
  if (userRole == 'creator' ||
      (userRole == 'admin' &&
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
