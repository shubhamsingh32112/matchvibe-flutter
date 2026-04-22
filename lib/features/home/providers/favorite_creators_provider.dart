import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/creator_model.dart';
import 'availability_provider.dart';
import 'home_provider.dart';

final favoriteCreatorsFeedMetaProvider = StateProvider<FeedPaginationMeta>(
  (_) => const FeedPaginationMeta.initial(),
);

class FavoriteCreatorsNotifier extends AsyncNotifier<List<CreatorModel>> {
  int _nextPage = 1;
  int _total = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _requestId = 0;
  List<CreatorModel> _items = const [];

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
      final page = await _fetchPage(_nextPage);
      if (localRequest != _requestId) return;
      _items = _dedupeById([..._items, ...page.items]);
      _nextPage = page.page + 1;
      _total = page.total ?? _items.length;
      _hasMore = page.hasMore;
      state = AsyncData(_items);
    } catch (e, st) {
      debugPrint('❌ [FAVORITES] Failed to load more favorites: $e');
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
    _publishMeta();
    final page = await _fetchPage(1);
    _items = _dedupeById(page.items);
    _nextPage = page.page + 1;
    _total = page.total ?? _items.length;
    _hasMore = page.hasMore;
    _publishMeta();
    return _items;
  }

  Future<_FavoriteCreatorPage> _fetchPage(int page) async {
    final response = await ref.read(homeApiGetProvider)(
      '/user/favorites/creators?page=$page&limit=$homeFeedPageSize',
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch favorite creators: status ${response.statusCode}',
      );
    }

    final data = response.data['data'] as Map<String, dynamic>? ?? const {};
    final creatorsData = data['creators'] as List? ?? const [];
    final creators = creatorsData
        .map((json) => CreatorModel.fromJson(json as Map<String, dynamic>))
        .toList();
    final pagination = data['pagination'] as Map<String, dynamic>?;

    final apiAvailability = <String, CreatorAvailability>{};
    for (final creator in creators) {
      if (creator.firebaseUid != null) {
        apiAvailability[creator.firebaseUid!] = creator.availability == 'online'
            ? CreatorAvailability.online
            : CreatorAvailability.busy;
      }
    }
    ref.read(creatorAvailabilityProvider.notifier).seedFromApi(apiAvailability);

    final currentPage = (pagination?['page'] as num?)?.toInt() ?? page;
    final total = (pagination?['total'] as num?)?.toInt();
    final totalPages = (pagination?['totalPages'] as num?)?.toInt() ?? currentPage;
    return _FavoriteCreatorPage(
      items: creators,
      page: currentPage,
      total: total,
      hasMore: currentPage < totalPages,
    );
  }

  void _publishMeta() {
    Future<void>.microtask(() {
      ref.read(favoriteCreatorsFeedMetaProvider.notifier).state = FeedPaginationMeta(
        page: _nextPage <= 1 ? 1 : _nextPage - 1,
        limit: homeFeedPageSize,
        total: _total,
        hasMore: _hasMore,
        isLoadingMore: _isLoadingMore,
      );
    });
  }

  List<CreatorModel> _dedupeById(List<CreatorModel> creators) {
    final byId = <String, CreatorModel>{};
    for (final creator in creators) {
      byId[creator.id] = creator;
    }
    return byId.values.toList(growable: false);
  }
}

final favoriteCreatorsProvider =
    AsyncNotifierProvider<FavoriteCreatorsNotifier, List<CreatorModel>>(
      FavoriteCreatorsNotifier.new,
    );

class _FavoriteCreatorPage {
  final List<CreatorModel> items;
  final int page;
  final int? total;
  final bool hasMore;

  const _FavoriteCreatorPage({
    required this.items,
    required this.page,
    this.total,
    required this.hasMore,
  });
}
