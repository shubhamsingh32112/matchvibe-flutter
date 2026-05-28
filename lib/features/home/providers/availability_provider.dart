import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/socket_service.dart';
import '../../creator/providers/creator_dashboard_provider.dart';
import '../../creator/providers/creator_status_provider.dart'
    as creator_self_status;
import '../../creator/providers/creator_presence_orchestrator_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/providers/wallet_pricing_provider.dart';
import '../../user/providers/user_availability_provider.dart';
import '../../../shared/models/app_update_model.dart';
import '../../../shared/providers/app_update_popup_provider.dart';
import '../../support/services/support_realtime_handler.dart';

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
  final Map<String, int> _versions = <String, int>{};

  /// Bulk-update from an [availability:batch] socket event (Redis snapshot).
  /// Merge is strictly version-gated: incoming.version must be greater.
  void updateBatch(Map<String, String> data, {Map<String, int>? versions}) {
    if (versions == null) {
      if (!kReleaseMode) {
        debugPrint(
          '⚠️ [AVAILABILITY] Ignoring unversioned availability:batch payload',
        );
      }
      return;
    }
    Map<String, CreatorAvailability>? newState;
    var changes = 0;
    for (final entry in data.entries) {
      final currentVersion = _versions[entry.key] ?? 0;
      final incomingVersion = versions[entry.key] ?? 0;
      if (incomingVersion <= currentVersion) {
        continue;
      }
      final v = entry.value == 'online'
          ? CreatorAvailability.online
          : CreatorAvailability.busy;
      if (state[entry.key] != v) {
        newState ??= Map<String, CreatorAvailability>.from(state);
        newState[entry.key] = v;
        changes++;
      }
      _versions[entry.key] = incomingVersion;
    }
    if (newState != null) {
      state = newState;
      _AvailabilityPerfProbe.recordEvent(changes);
    }
  }

  void updateBatchV2(Map<String, Map<String, dynamic>> data) {
    final statusMap = <String, String>{};
    final versions = <String, int>{};
    data.forEach((creatorId, payload) {
      final status = payload['status']?.toString() == 'online'
          ? 'online'
          : 'busy';
      statusMap[creatorId] = status;
      versions[creatorId] = (payload['version'] as num?)?.toInt() ?? 0;
    });
    updateBatch(statusMap, versions: versions);
  }

  /// Single update from a [creator:status] socket event.
  void updateSingle(String creatorId, String status, {int? version}) {
    if (version == null) {
      if (!kReleaseMode) {
        debugPrint(
          '⚠️ [AVAILABILITY] Ignoring unversioned creator:status for $creatorId',
        );
      }
      return;
    }
    final incomingVersion = version;
    final currentVersion = _versions[creatorId] ?? 0;
    if (incomingVersion <= currentVersion) {
      return;
    }
    final newAvailability = status == 'online'
        ? CreatorAvailability.online
        : CreatorAvailability.busy;

    // Always advance monotonic version even when status stays unchanged.
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
    _versions[creatorId] = incomingVersion;
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

  /// Instant fan UI while call lifecycle runs — server versioned events still win when higher.
  void applyCallLifecycleHint(String creatorId, CreatorAvailability availability) {
    final nextVersion = (_versions[creatorId] ?? 0) + 1;
    updateSingle(
      creatorId,
      availability == CreatorAvailability.online ? 'online' : 'busy',
      version: nextVersion,
    );
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

  void onSocketConnected() {
    final user = ref.read(authProvider).user;
    final isCreator =
        user != null && (user.role == 'creator' || user.role == 'admin');
    if (isCreator) {
      ref
          .read(creator_self_status.creatorStatusProvider.notifier)
          .updateFromSocketConnection(true);
      unawaited(
        ref
            .read(creatorPresenceOrchestratorProvider)
            .refreshPresence(reason: 'socket_connected'),
      );
    }
  }

  void onSocketDisconnected() {
    final user = ref.read(authProvider).user;
    final isCreator =
        user != null && (user.role == 'creator' || user.role == 'admin');
    if (isCreator) {
      ref
          .read(creator_self_status.creatorStatusProvider.notifier)
          .updateFromSocketConnection(false);
    }
  }

  service.onConnected = onSocketConnected;
  service.onDisconnected = onSocketDisconnected;

  // Wire socket callbacks → Riverpod state
  service.onAvailabilityBatch = (data) {
    // Ignore unversioned v1 batch to prevent stale overwrite paths.
    if (!kReleaseMode) {
      debugPrint(
        '⚠️ [SOCKET→PROVIDER] Ignoring unversioned availability:batch payload',
      );
    }
  };
  service.onAvailabilityBatchV2 = (data) {
    ref.read(creatorAvailabilityProvider.notifier).updateBatchV2(data);
  };
  service.onCreatorStatus = (creatorId, status) {
    if (!kReleaseMode) {
      debugPrint(
        '⚠️ [SOCKET→PROVIDER] Ignoring unversioned creator:status for $creatorId',
      );
    }
  };
  service.onCreatorStatusV2 =
      (creatorId, status, {int? version, int? updatedAt}) {
        ref
            .read(creatorAvailabilityProvider.notifier)
            .updateSingle(creatorId, status, version: version);
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
    final auth = ref.read(authProvider);
    if (auth.createdNow) {
      final updateId = data['id']?.toString() ?? 'unknown';
      debugPrint(
        '[AppUpdate] socket_suppressed createdNow=true updateId=$updateId',
      );
      return;
    }
    ref
        .read(appUpdatePopupProvider.notifier)
        .setPendingUpdate(AppUpdateModel.fromJson(data), source: 'socket');
  };

  service.onSupportTicketUpdated = (data) {
    handleSupportTicketSocketUpdate(ref, data);
  };

  ref.onDispose(() {
    service.disconnect();
  });

  return service;
});
