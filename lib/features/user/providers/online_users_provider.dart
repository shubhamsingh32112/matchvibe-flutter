import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/profile_model.dart';
import './user_availability_provider.dart';

class OnlineUsersNotifier extends AsyncNotifier<List<UserProfileModel>> {
  final ApiClient _apiClient = ApiClient();
  final Map<String, UserProfileModel> _onlineByUid = {};

  Timer? _resolveDebounce;
  final Set<String> _pendingResolveUids = {};
  bool _resolveInFlight = false;

  @override
  Future<List<UserProfileModel>> build() async {
    ref.onDispose(() {
      _resolveDebounce?.cancel();
      _resolveDebounce = null;
    });

    // When presence changes, incrementally add/remove users.
    ref.listen<Map<String, UserAvailability>>(
      userAvailabilityProvider,
      (prev, next) {
        final before = prev ?? const <String, UserAvailability>{};
        _applyPresenceDiff(before, next);
      },
    );

    final snapshot = await _fetchOnlineUsersSnapshot();
    _onlineByUid
      ..clear()
      ..addEntries(
        snapshot
            .where((u) => u.firebaseUid != null && u.firebaseUid!.isNotEmpty)
            .map((u) => MapEntry(u.firebaseUid!, u)),
      );
    return _sortedUsers();
  }

  List<UserProfileModel> _sortedUsers() {
    final list = _onlineByUid.values.toList(growable: false);
    list.sort((a, b) {
      final an = (a.username ?? '').toLowerCase();
      final bn = (b.username ?? '').toLowerCase();
      final c = an.compareTo(bn);
      if (c != 0) return c;
      return a.id.compareTo(b.id);
    });
    return list;
  }

  void _applyPresenceDiff(
    Map<String, UserAvailability> before,
    Map<String, UserAvailability> after,
  ) {
    final removed = <String>[];
    final added = <String>[];

    // Detect offline transitions (or removals).
    for (final entry in before.entries) {
      final uid = entry.key;
      final prevStatus = entry.value;
      final nextStatus = after[uid];
      if (prevStatus == UserAvailability.online &&
          nextStatus != UserAvailability.online) {
        removed.add(uid);
      }
    }

    // Detect online transitions.
    for (final entry in after.entries) {
      final uid = entry.key;
      final nextStatus = entry.value;
      final prevStatus = before[uid];
      if (nextStatus == UserAvailability.online &&
          prevStatus != UserAvailability.online) {
        added.add(uid);
      }
    }

    if (removed.isNotEmpty) {
      for (final uid in removed) {
        _onlineByUid.remove(uid);
      }
      state = AsyncValue.data(_sortedUsers());
    }

    if (added.isNotEmpty) {
      for (final uid in added) {
        // If we already have profile, no need to resolve.
        if (_onlineByUid.containsKey(uid)) continue;
        _pendingResolveUids.add(uid);
      }
      _scheduleResolve();
    }
  }

  void _scheduleResolve() {
    // Debounce bursts of presence events.
    _resolveDebounce?.cancel();
    _resolveDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_resolvePendingUsers());
    });
  }

  Future<void> refreshOnlineUsers() async {
    // Explicit pull-to-refresh still fetches the snapshot.
    try {
      final snapshot = await _fetchOnlineUsersSnapshot();
      _onlineByUid
        ..clear()
        ..addEntries(
          snapshot
              .where((u) => u.firebaseUid != null && u.firebaseUid!.isNotEmpty)
              .map((u) => MapEntry(u.firebaseUid!, u)),
        );
      state = AsyncValue.data(_sortedUsers());
    } catch (e, st) {
      // Keep last good list if we have one; otherwise surface error.
      final prev = state;
      if (prev is AsyncData<List<UserProfileModel>>) {
        debugPrint('⚠️  [ONLINE USERS] Refresh failed, keeping last snapshot: $e');
        return;
      }
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _resolvePendingUsers() async {
    if (_resolveInFlight) return;
    if (_pendingResolveUids.isEmpty) return;
    _resolveInFlight = true;

    final uids = _pendingResolveUids.toList(growable: false);
    _pendingResolveUids.clear();

    try {
      final response = await _apiClient.post(
        '/availability/resolve-users',
        data: {'firebaseUids': uids},
      );

      final data = response.data;
      if (data is! Map) return;
      final payload = data['data'];
      if (payload is! Map) return;
      final rawUsers = payload['users'];
      if (rawUsers is! List) return;

      for (final m in rawUsers.whereType<Map>()) {
        final user = UserProfileModel.fromJson(Map<String, dynamic>.from(m));
        final uid = user.firebaseUid;
        if (uid == null || uid.isEmpty) continue;

        // Only add if still online according to latest availability map.
        final availability = ref.read(userAvailabilityProvider);
        if (availability[uid] != UserAvailability.online) continue;

        _onlineByUid[uid] = user;
      }

      state = AsyncValue.data(_sortedUsers());
    } catch (e) {
      debugPrint('⚠️  [ONLINE USERS] Resolve failed: $e');
      // Re-queue on next presence change; don't hard-fail the list.
    } finally {
      _resolveInFlight = false;
    }
  }

  Future<List<UserProfileModel>> _fetchOnlineUsersSnapshot() async {
    final response = await _apiClient.get(
      '/availability/online-users',
      queryParameters: const {
        'limit': 2000,
        'cursor': 0,
      },
    );

    final data = response.data;
    if (data is! Map) {
      return const [];
    }

    final payload = data['data'];
    if (payload is! Map) {
      return const [];
    }

    final rawUsers = payload['users'];
    if (rawUsers is! List) {
      return const [];
    }

    return rawUsers
        .whereType<Map>()
        .map((m) => UserProfileModel.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }
}

/// Creator-facing: returns profiles of currently-online users.
final onlineUsersProvider =
    AsyncNotifierProvider<OnlineUsersNotifier, List<UserProfileModel>>(
  OnlineUsersNotifier.new,
);

