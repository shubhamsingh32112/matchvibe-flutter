import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/socket_service.dart';
import '../../creator/providers/creator_dashboard_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/providers/wallet_pricing_provider.dart';
import '../../user/providers/user_availability_provider.dart';
import '../../../shared/models/app_update_model.dart';
import '../../../shared/providers/app_update_popup_provider.dart';
// 🔥 CRITICAL FIX: Import socket service provider to update creator's own status
import '../../../core/services/availability_socket_service.dart'
    as socket_service;

// ── Enum ──────────────────────────────────────────────────────────────────
enum CreatorAvailability { online, busy }

class _AvailabilityPerfProbe {
  static int _eventCount = 0;
  static DateTime _windowStart = DateTime.now();

  static void recordEvent(int count) {
    if (kReleaseMode || count <= 0) return;
    _eventCount += count;
    final now = DateTime.now();
    final elapsedMs = now.difference(_windowStart).inMilliseconds;
    if (elapsedMs < 5000) return;
    final eventsPerSecond = (_eventCount * 1000) / elapsedMs;
    debugPrint(
      '📈 [AVAILABILITY PERF] eventsPerSecond=${eventsPerSecond.toStringAsFixed(1)} windowMs=$elapsedMs',
    );
    _eventCount = 0;
    _windowStart = now;
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────
class CreatorAvailabilityNotifier
    extends StateNotifier<Map<String, CreatorAvailability>> {
  CreatorAvailabilityNotifier() : super({});

  /// Bulk-update from an [availability:batch] socket event (Redis snapshot).
  /// Socket batch is authoritative snapshot and should overwrite stale seeded values.
  void updateBatch(Map<String, String> data) {
    Map<String, CreatorAvailability>? newState;
    var changes = 0;
    for (final entry in data.entries) {
      final v = entry.value == 'online'
          ? CreatorAvailability.online
          : CreatorAvailability.busy;
      if (state[entry.key] == v) continue;
      newState ??= Map<String, CreatorAvailability>.from(state);
      newState[entry.key] = v;
      changes++;
    }
    if (newState != null) {
      state = newState;
      _AvailabilityPerfProbe.recordEvent(changes);
    }
  }

  /// Single update from a [creator:status] socket event.
  void updateSingle(String creatorId, String status) {
    final newAvailability = status == 'online'
        ? CreatorAvailability.online
        : CreatorAvailability.busy;

    // Only update if status actually changed (prevents unnecessary rebuilds)
    if (state[creatorId] != newAvailability) {
      final newState = Map<String, CreatorAvailability>.from(state);
      newState[creatorId] = newAvailability;
      state = newState;
      _AvailabilityPerfProbe.recordEvent(1);
      debugPrint(
        '📡 [AVAILABILITY] Updated creator status: $creatorId → $status',
      );
    } else {
      debugPrint(
        '📡 [AVAILABILITY] Creator status unchanged: $creatorId → $status (skipping update)',
      );
    }
  }

  /// Seed from REST (Redis-backed API). Never overwrites live socket map entries.
  void seedFromApi(Map<String, CreatorAvailability> data) {
    if (data.isEmpty) return;
    Map<String, CreatorAvailability>? newState;
    for (final e in data.entries) {
      if (state.containsKey(e.key)) continue;
      newState ??= Map<String, CreatorAvailability>.from(state);
      newState[e.key] = e.value;
    }
    if (newState != null) {
      state = newState;
    }
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
final creatorAvailabilityProvider =
    StateNotifierProvider<
      CreatorAvailabilityNotifier,
      Map<String, CreatorAvailability>
    >((ref) {
      return CreatorAvailabilityNotifier();
    });

final creatorStatusProvider = Provider.family<CreatorAvailability, String?>((
  ref,
  creatorId,
) {
  if (creatorId == null || creatorId.isEmpty) {
    return CreatorAvailability.busy;
  }
  return ref.watch(
    creatorAvailabilityProvider.select(
      (map) => map[creatorId] ?? CreatorAvailability.busy,
    ),
  );
});

/// Global [SocketService] instance wired to the availability notifier.
/// Created once, lives for the entire app session (not autoDispose).
final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();

  // Wire socket callbacks → Riverpod state
  service.onAvailabilityBatch = (data) {
    // Update provider from availability_provider.dart (for user homepage)
    ref.read(creatorAvailabilityProvider.notifier).updateBatch(data);

    // 🔥 CRITICAL FIX: Also update provider from availability_socket_service.dart
    // This ensures creator's own status updates instantly when SocketService receives batch events
    try {
      final batchMap = <String, socket_service.CreatorAvailability>{};
      for (final entry in data.entries) {
        batchMap[entry.key] = entry.value == 'online'
            ? socket_service.CreatorAvailability.online
            : socket_service.CreatorAvailability.busy;
      }
      ref
          .read(socket_service.creatorAvailabilityProvider.notifier)
          .updateAll(batchMap);
      debugPrint(
        '✅ [SOCKET→PROVIDER] Successfully updated socket service provider with batch',
      );
    } catch (e) {
      debugPrint(
        '⚠️  [SOCKET→PROVIDER] Could not update socket service provider batch: $e',
      );
      // Non-critical - AvailabilitySocketService will also handle the event if connected
    }
  };
  service.onCreatorStatus = (creatorId, status) {
    debugPrint(
      '📡 [SOCKET→PROVIDER] Received creator:status event: $creatorId → $status',
    );
    try {
      // Update provider from availability_provider.dart (for user homepage)
      ref
          .read(creatorAvailabilityProvider.notifier)
          .updateSingle(creatorId, status);
      debugPrint(
        '✅ [SOCKET→PROVIDER] Successfully updated home provider for $creatorId',
      );

      // 🔥 CRITICAL FIX: Also update provider from availability_socket_service.dart
      // This ensures creator's own status updates instantly when SocketService receives events
      // This is especially important if AvailabilitySocketService is not connected or initialized
      try {
        final statusEnum = status == 'online'
            ? socket_service.CreatorAvailability.online
            : socket_service.CreatorAvailability.busy;
        ref
            .read(socket_service.creatorAvailabilityProvider.notifier)
            .update(creatorId, statusEnum);
        debugPrint(
          '✅ [SOCKET→PROVIDER] Successfully updated socket service provider for $creatorId',
        );
      } catch (e) {
        debugPrint(
          '⚠️  [SOCKET→PROVIDER] Could not update socket service provider: $e',
        );
        // Non-critical - AvailabilitySocketService will also handle the event if connected
      }
    } catch (e) {
      debugPrint('❌ [SOCKET→PROVIDER] Failed to update provider: $e');
    }
  };

  /// Fan presence — same payloads as [AvailabilitySocketService] (`user:status` / batch).
  service.onUserStatus = (firebaseUid, status) {
    final ua = status == 'online'
        ? UserAvailability.online
        : UserAvailability.offline;
    ref.read(userAvailabilityProvider.notifier).update(firebaseUid, ua);
  };
  service.onUserAvailabilityBatch = (batch) {
    ref.read(userAvailabilityProvider.notifier).updateBatch(batch);
  };

  // ── Creator data sync: invalidate dashboard + refresh user on data_updated ──
  service.onCreatorDataUpdated = (data) {
    debugPrint(
      '📊 [SOCKET→PROVIDER] creator:data_updated received, reason: ${data['reason']}',
    );
    // Invalidate the central dashboard provider so all watchers get fresh data
    // This updates earnings, tasks, and stats (but NOT coins - handled separately)
    ref.invalidate(creatorDashboardProvider);

    if (data['reason'] == 'profile_updated') {
      ref.read(authProvider.notifier).refreshUser();
    }

    // 🔥 FIX: Only refresh auth user if coins are provided in the event
    // Otherwise, coins_updated event will handle coin updates instantly
    if (data['coins'] != null) {
      final coins = (data['coins'] as num?)?.toInt();
      if (coins != null) {
        // Update coins optimistically for instant UI update
        ref.read(authProvider.notifier).updateCoinsOptimistically(coins);
      }
    }

    // For other data changes (earnings, tasks), dashboard invalidation is sufficient
    // No need for full auth refresh - saves API calls and improves performance
  };

  // ── Coins updated: update coins instantly without full refresh ──
  service.onCoinsUpdated = (data) {
    debugPrint('💰 [SOCKET→PROVIDER] coins_updated received: $data');
    // 🔥 FIX: Update coins optimistically for instant UI update
    // This avoids full API refresh and provides instant feedback
    final coins = (data['coins'] as num?)?.toInt();
    if (coins != null) {
      ref.read(authProvider.notifier).updateCoinsOptimistically(coins);
      debugPrint('✅ [SOCKET→PROVIDER] Coins updated instantly: $coins');
    } else {
      // Fallback: full refresh if coins not provided
      debugPrint(
        '⚠️  [SOCKET→PROVIDER] coins_updated missing coins, falling back to refresh',
      );
      ref.read(authProvider.notifier).refreshUser();
    }
  };

  service.onWalletPricingUpdated = (data) {
    debugPrint('💳 [SOCKET→PROVIDER] wallet_pricing_updated received: $data');
    ref.invalidate(walletPricingProvider);
  };

  service.onAppUpdatePublished = (data) {
    debugPrint('🆕 [SOCKET→PROVIDER] app_update:published received');
    ref.read(appUpdatePopupProvider.notifier).setPendingUpdate(
          AppUpdateModel.fromJson(data),
        );
  };

  ref.onDispose(() {
    service.disconnect();
  });

  return service;
});
