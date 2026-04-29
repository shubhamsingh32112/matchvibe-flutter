import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/home_provider.dart';

final presenceHydrationServiceProvider = Provider<PresenceHydrationService>((ref) {
  return PresenceHydrationService(apiGet: ref.read(homeApiGetProvider));
});

class PresenceHydrationService {
  PresenceHydrationService({required HomeApiGet apiGet}) : _apiGet = apiGet;

  final HomeApiGet _apiGet;

  /// Single round-trip: all creator Firebase UIDs for presence (no gallery / Storage work).
  Future<List<String>> collectCreatorFirebaseUids() async {
    final response = await _apiGet('/creator/uids');
    if (response.statusCode != 200) {
      throw Exception(
        'Presence hydration failed at /creator/uids with status ${response.statusCode}',
      );
    }
    final body = response.data as Map<String, dynamic>? ?? const {};
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    final raw = data['firebaseUids'];
    if (raw is! List) return const [];
    final ids = <String>{};
    for (final e in raw) {
      final s = e?.toString().trim();
      if (s != null && s.isNotEmpty) ids.add(s);
    }
    if (kDebugMode) {
      debugPrint(
        '📡 [PRESENCE HYDRATION] Collected ${ids.length} uid(s) from /creator/uids',
      );
    }
    return ids.toList(growable: false);
  }

  Future<List<String>> collectUserFirebaseUids() async {
    return _collectFirebaseUidsFromPagedList(
      pathBuilder: (page) =>
          '/user/list?page=$page&limit=$_presenceHydrationPageSize',
      listSelector: (data) => data['users'] as List? ?? const [],
    );
  }

  static const int _presenceHydrationPageSize = 50;
  static const int _presenceHydrationMaxPages = 8;

  Future<List<String>> _collectFirebaseUidsFromPagedList({
    required String Function(int page) pathBuilder,
    required List<dynamic> Function(Map<String, dynamic> data) listSelector,
  }) async {
    final ids = <String>{};
    var page = 1;
    var hasMore = true;

    while (hasMore && page <= _presenceHydrationMaxPages) {
      final path = pathBuilder(page);
      final response = await _apiGet(path);
      if (response.statusCode != 200) {
        throw Exception(
          'Presence hydration failed at $path with status ${response.statusCode}',
        );
      }
      final body = response.data as Map<String, dynamic>? ?? const {};
      final data = body['data'] as Map<String, dynamic>? ?? const {};
      final rows = listSelector(data);
      for (final row in rows) {
        if (row is! Map) continue;
        final uid = row['firebaseUid']?.toString();
        if (uid != null && uid.isNotEmpty) {
          ids.add(uid);
        }
      }

      final pagination = data['pagination'] as Map<String, dynamic>?;
      if (pagination == null) {
        hasMore = false;
      } else {
        final currentPage = (pagination['page'] as num?)?.toInt() ?? page;
        final totalPages =
            (pagination['totalPages'] as num?)?.toInt() ?? currentPage;
        hasMore = currentPage < totalPages;
      }
      page += 1;
    }

    if (kDebugMode) {
      debugPrint(
        '📡 [PRESENCE HYDRATION] Collected ${ids.length} user uid(s) with page sweep',
      );
    }
    return ids.toList(growable: false);
  }
}
