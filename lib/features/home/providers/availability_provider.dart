import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/socket_service.dart';
import '../../creator/providers/creator_dashboard_provider.dart';
import '../../auth/providers/auth_provider.dart';

// ── Enum ──────────────────────────────────────────────────────────────────
enum CreatorAvailability { online, busy }

// ── Notifier ──────────────────────────────────────────────────────────────
class CreatorAvailabilityNotifier
    extends StateNotifier<Map<String, CreatorAvailability>> {
  CreatorAvailabilityNotifier() : super({});

  /// Bulk-update from an [availability:batch] socket event.
  void updateBatch(Map<String, String> data) {
    final newState = Map<String, CreatorAvailability>.from(state);
    for (final entry in data.entries) {
      newState[entry.key] = entry.value == 'online'
          ? CreatorAvailability.online
          : CreatorAvailability.busy;
    }
    state = newState;
  }

  /// Single update from a [creator:status] socket event.
  void updateSingle(String creatorId, String status) {
    final newState = Map<String, CreatorAvailability>.from(state);
    newState[creatorId] =
        status == 'online' ? CreatorAvailability.online : CreatorAvailability.busy;
    state = newState;
  }

  /// Seed initial availability from the REST API response.
  /// Runs once on first load; after that socket events are authoritative.
  void seedFromApi(Map<String, CreatorAvailability> data) {
    if (state.isNotEmpty) return; // Already seeded by socket events
    state = Map<String, CreatorAvailability>.from(data);
  }

  /// Get availability for one creator. **Default = busy**.
  CreatorAvailability getAvailability(String? creatorId) {
    if (creatorId == null) return CreatorAvailability.busy;
    return state[creatorId] ?? CreatorAvailability.busy;
  }
}

// ── Providers ─────────────────────────────────────────────────────────────

/// The reactive availability map: `{ firebaseUid → online | busy }`.
/// Widgets that call `ref.watch(creatorAvailabilityProvider)` will rebuild
/// whenever a batch or incremental update arrives via Socket.IO.
final creatorAvailabilityProvider = StateNotifierProvider<
    CreatorAvailabilityNotifier, Map<String, CreatorAvailability>>((ref) {
  return CreatorAvailabilityNotifier();
});

/// Global [SocketService] instance wired to the availability notifier.
/// Created once, lives for the entire app session (not autoDispose).
final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();

  // Wire socket callbacks → Riverpod state
  service.onAvailabilityBatch = (data) {
    ref.read(creatorAvailabilityProvider.notifier).updateBatch(data);
  };
  service.onCreatorStatus = (creatorId, status) {
    ref.read(creatorAvailabilityProvider.notifier).updateSingle(creatorId, status);
  };

  // ── Creator data sync: invalidate dashboard + refresh user on data_updated ──
  service.onCreatorDataUpdated = (data) {
    debugPrint('📊 [SOCKET→PROVIDER] creator:data_updated received, reason: ${data['reason']}');
    // Invalidate the central dashboard provider so all watchers get fresh data
    ref.invalidate(creatorDashboardProvider);
    // Also refresh the auth user so coin balance updates everywhere
    ref.read(authProvider.notifier).refreshUser();
  };

  ref.onDispose(() {
    service.disconnect();
  });

  return service;
});
