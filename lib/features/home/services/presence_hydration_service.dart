import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/home_provider.dart';

const int _presenceHydrationPageSize = 50;
const int _presenceHydrationMaxPages = 8;

final presenceHydrationServiceProvider = Provider<PresenceHydrationService>((ref) {
  return PresenceHydrationService(apiGet: ref.read(homeApiGetProvider));
});

class PresenceHydrationService {
  PresenceHydrationService({required HomeApiGet apiGet}) : _apiGet = apiGet;

  final HomeApiGet _apiGet;

  Future<List<String>> collectCreatorFirebaseUids() async {
    return _collectFirebaseUids(
      pathBuilder: (page) =>
          '/creator?page=$page&limit=$_presenceHydrationPageSize',
      listSelector: (data) => data['creators'] as List? ?? const [],
    );
  }

  Future<List<String>> collectUserFirebaseUids() async {
    return _collectFirebaseUids(
      pathBuilder: (page) =>
          '/user/list?page=$page&limit=$_presenceHydrationPageSize',
      listSelector: (data) => data['users'] as List? ?? const [],
    );
  }

  Future<List<String>> _collectFirebaseUids({
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
        '📡 [PRESENCE HYDRATION] Collected ${ids.length} uid(s) with page sweep',
      );
    }
    return ids.toList(growable: false);
  }
}
