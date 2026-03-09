import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Enum ──────────────────────────────────────────────────────────────────
enum UserAvailability { online, offline }

// ── Notifier ──────────────────────────────────────────────────────────────
class UserAvailabilityNotifier
    extends StateNotifier<Map<String, UserAvailability>> {
  UserAvailabilityNotifier() : super({});

  /// Guard: prevents API re-seeding from overwriting newer socket data.
  /// Set to true after the first API seed; reset only on clear() (logout).
  bool _hasSeeded = false;

  /// Seed availability from an API response.
  /// Only runs ONCE – subsequent calls (e.g. after usersProvider invalidation)
  /// are no-ops so that fresher socket data is never overwritten.
  void seedFromApi(Map<String, UserAvailability> apiData) {
    if (_hasSeeded) {
      debugPrint('📡 [USER AVAILABILITY] Skipping API re-seed (already seeded, socket is authoritative)');
      return;
    }
    _hasSeeded = true;
    state = {...state, ...apiData};
    debugPrint('📡 [USER AVAILABILITY] Seeded from API: ${apiData.length} user(s)');
  }

  /// Update a single user's availability.
  /// Called by socket handlers – ALWAYS overwrites (socket is authoritative).
  void update(String firebaseUid, UserAvailability status) {
    state = {...state, firebaseUid: status};
    debugPrint('📡 [USER AVAILABILITY] Updated: $firebaseUid → $status');
  }

  /// Bulk update from user:availability:batch event
  void updateBatch(Map<String, String> data) {
    final newState = Map<String, UserAvailability>.from(state);
    for (final entry in data.entries) {
      newState[entry.key] = entry.value == 'online'
          ? UserAvailability.online
          : UserAvailability.offline;
    }
    state = newState;
    debugPrint('📡 [USER AVAILABILITY] Bulk update: ${data.length} user(s)');
  }

  /// Get availability for a specific user
  /// Returns 'offline' if not found (safe default)
  UserAvailability get(String? firebaseUid) {
    if (firebaseUid == null) return UserAvailability.offline;
    return state[firebaseUid] ?? UserAvailability.offline;
  }

  /// Clear all availability (e.g., on disconnect / logout).
  /// Resets the hasSeeded flag so the next API fetch can seed again.
  void clear() {
    _hasSeeded = false;
    state = {};
    debugPrint('📡 [USER AVAILABILITY] Cleared all (hasSeeded reset)');
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
