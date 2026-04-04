import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Enum ──────────────────────────────────────────────────────────────────
enum UserAvailability { online, offline }

// ── Notifier ──────────────────────────────────────────────────────────────
class UserAvailabilityNotifier
    extends StateNotifier<Map<String, UserAvailability>> {
  UserAvailabilityNotifier() : super({});

  /// Seed from REST (Redis-backed API). Never overwrites live socket map entries.
  void seedFromApi(Map<String, UserAvailability> apiData) {
    if (apiData.isEmpty) return;
    final newState = Map<String, UserAvailability>.from(state);
    for (final e in apiData.entries) {
      newState.putIfAbsent(e.key, () => e.value);
    }
    state = newState;
    debugPrint('📡 [USER AVAILABILITY] Merged API seed: ${apiData.length} user(s) (socket wins on conflict)');
  }

  /// Update a single user's availability.
  /// Called by socket handlers – ALWAYS overwrites (socket is authoritative).
  void update(String firebaseUid, UserAvailability status) {
    state = {...state, firebaseUid: status};
    debugPrint('📡 [USER AVAILABILITY] Updated: $firebaseUid → $status');
  }

  /// Bulk update from user:availability:batch (Redis snapshot over socket).
  /// Socket-first: does not overwrite keys already set by live [user:status].
  void updateBatch(Map<String, String> data) {
    final newState = Map<String, UserAvailability>.from(state);
    for (final entry in data.entries) {
      final v = entry.value == 'online'
          ? UserAvailability.online
          : UserAvailability.offline;
      newState.putIfAbsent(entry.key, () => v);
    }
    state = newState;
    debugPrint('📡 [USER AVAILABILITY] Batch merge: ${data.length} user(s) (socket wins on conflict)');
  }

  /// Get availability for a specific user
  /// Returns 'offline' if not found (safe default)
  UserAvailability get(String? firebaseUid) {
    if (firebaseUid == null) return UserAvailability.offline;
    return state[firebaseUid] ?? UserAvailability.offline;
  }

  /// Clear all availability (e.g., on disconnect / logout).
  void clear() {
    state = {};
    debugPrint('📡 [USER AVAILABILITY] Cleared all');
  }
}

// ── Providers ─────────────────────────────────────────────────────────────

/// The reactive availability map: `{ firebaseUid → online | offline }`.
/// Widgets that call `ref.watch(userAvailabilityProvider)` will rebuild
/// whenever a batch or incremental update arrives via Socket.IO.
final userAvailabilityProvider = StateNotifierProvider<
    UserAvailabilityNotifier, Map<String, UserAvailability>>((ref) {
  return UserAvailabilityNotifier();
});

/// 🔥 CONVENIENCE PROVIDER: Get availability for a specific user
/// 
/// Usage:
/// ```dart
/// final status = ref.watch(userStatusProvider(firebaseUid));
/// ```
/// 
/// Returns UserAvailability.offline if not found (safe default)
final userStatusProvider = Provider.family<UserAvailability, String?>((ref, firebaseUid) {
  if (firebaseUid == null) return UserAvailability.offline;
  
  final availabilityMap = ref.watch(userAvailabilityProvider);
  return availabilityMap[firebaseUid] ?? UserAvailability.offline;
});

/// 🔥 CONVENIENCE PROVIDER: Check if user is online
/// 
/// Usage:
/// ```dart
/// final isOnline = ref.watch(isUserOnlineProvider(firebaseUid));
/// ```
final isUserOnlineProvider = Provider.family<bool, String?>((ref, firebaseUid) {
  if (firebaseUid == null) return false;
  
  final status = ref.watch(userStatusProvider(firebaseUid));
  return status == UserAvailability.online;
});
