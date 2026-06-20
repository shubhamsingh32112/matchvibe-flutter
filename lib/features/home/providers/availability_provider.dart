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
import '../../moments/services/moments_realtime_handler.dart';
import '../../vip/providers/vip_call_queue_provider.dart';
import '../../../core/config/app_config_provider.dart';

// ── Enum ──────────────────────────────────────────────────────────────────
enum CreatorAvailability { online, onCall, offline }

String? _normalizeFirebaseUid(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

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
      final creatorId = _normalizeFirebaseUid(entry.key);
      if (creatorId == null) continue;
      final currentVersion = _versions[creatorId] ?? -1;
      final incomingVersion =
          versions[creatorId] ?? versions[entry.key] ?? 0;
      if (incomingVersion <= currentVersion) {
        continue;
      }
      final v = entry.value == 'online'
          ? CreatorAvailability.online
          : entry.value == 'on_call'
          ? CreatorAvailability.onCall
          : CreatorAvailability.offline;
      if (state[creatorId] != v) {
        newState ??= Map<String, CreatorAvailability>.from(state);
        newState[creatorId] = v;
        changes++;
      }
      _versions[creatorId] = incomingVersion;
    }
    if (newState != null) {
      state = newState;
      _AvailabilityPerfProbe.recordEvent(changes);
    }
  }

  void updateBatchV2(Map<String, Map<String, dynamic>> data) {
    Map<String, CreatorAvailability>? newState;
    var changes = 0;
    data.forEach((creatorId, payload) {
      final normalizedCreatorId = _normalizeFirebaseUid(creatorId);
      if (normalizedCreatorId == null) return;
      final status = payload['status']?.toString() == 'online'
          ? CreatorAvailability.online
          : payload['status']?.toString() == 'on_call'
          ? CreatorAvailability.onCall
          : CreatorAvailability.offline;
      final incomingVersion = (payload['version'] as num?)?.toInt() ?? 0;
      final currentVersion = _versions[normalizedCreatorId] ?? -1;
      final currentStatus =
          state[normalizedCreatorId] ?? CreatorAvailability.offline;
      final shouldApply = incomingVersion > currentVersion;
      if (!shouldApply) {
        return;
      }
      if (currentStatus != status) {
        newState ??= Map<String, CreatorAvailability>.from(state);
        newState![normalizedCreatorId] = status;
        changes++;
      }
      _versions[normalizedCreatorId] = incomingVersion;
    });
    if (newState != null) {
      state = newState!;
      _AvailabilityPerfProbe.recordEvent(changes);
    }
  }

  /// Single update from a [creator:status] socket event.
  void updateSingle(String creatorId, String status, {int? version}) {
    final normalizedCreatorId = _normalizeFirebaseUid(creatorId);
    if (normalizedCreatorId == null) return;
    if (version == null) {
      if (!kReleaseMode) {
        debugPrint(
          '⚠️ [AVAILABILITY] Ignoring unversioned creator:status for $normalizedCreatorId',
        );
      }
      return;
    }
    final incomingVersion = version;
    final currentVersion = _versions[normalizedCreatorId] ?? -1;
    if (incomingVersion <= currentVersion) {
      return;
    }
    final newAvailability = status == 'online'
        ? CreatorAvailability.online
        : status == 'on_call'
        ? CreatorAvailability.onCall
        : CreatorAvailability.offline;

    // Always advance monotonic version even when status stays unchanged.
    if (state[normalizedCreatorId] != newAvailability) {
      final newState = Map<String, CreatorAvailability>.from(state);
      newState[normalizedCreatorId] = newAvailability;
      state = newState;
      _AvailabilityPerfProbe.recordEvent(1);
      debugPrint(
        '📡 [AVAILABILITY] Updated creator status: $normalizedCreatorId → $status',
      );
    } else {
      debugPrint(
        '📡 [AVAILABILITY] Creator status unchanged: $normalizedCreatorId → $status (skipping update)',
      );
    }
    _versions[normalizedCreatorId] = incomingVersion;
  }

  /// Seed from REST (Redis-backed API). Never overwrites live socket map entries.
  void seedFromApi(Map<String, CreatorAvailability> data) {
    if (data.isEmpty) return;
    Map<String, CreatorAvailability>? newState;
    for (final e in data.entries) {
      final creatorId = _normalizeFirebaseUid(e.key);
      if (creatorId == null) continue;
      final currentVersion = _versions[creatorId] ?? -1;
      final existing = state[creatorId];
      final shouldApplySeed = existing == null || currentVersion < 0;
      if (!shouldApplySeed) continue;
      if (existing == e.value && currentVersion < 0) continue;
      newState ??= Map<String, CreatorAvailability>.from(state);
      newState[creatorId] = e.value;
      _versions[creatorId] = -1;
    }
    if (newState != null) {
      state = newState;
    }
  }

  /// Get availability for one creator. **Default = offline**.
  CreatorAvailability getAvailability(String? creatorId) {
    final normalizedCreatorId = _normalizeFirebaseUid(creatorId);
    if (normalizedCreatorId == null) return CreatorAvailability.offline;
    return state[normalizedCreatorId] ?? CreatorAvailability.offline;
  }

  /// Instant fan UI while call lifecycle runs — server versioned events still win when higher.
  void applyCallLifecycleHint(String creatorId, CreatorAvailability availability) {
    final normalizedCreatorId = _normalizeFirebaseUid(creatorId);
    if (normalizedCreatorId == null) return;
    final nextVersion = (_versions[normalizedCreatorId] ?? 0) + 1;
    updateSingle(
      normalizedCreatorId,
      availability == CreatorAvailability.online
          ? 'online'
          : availability == CreatorAvailability.onCall
          ? 'on_call'
          : 'offline',
      version: nextVersion,
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────

/// The reactive availability map: `{ firebaseUid → online | on_call | offline }`.
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
  final normalizedCreatorId = _normalizeFirebaseUid(creatorId);
  if (normalizedCreatorId == null) {
    return CreatorAvailability.offline;
  }
  return ref.watch(
    creatorAvailabilityProvider.select(
      (map) => map[normalizedCreatorId] ?? CreatorAvailability.offline,
    ),
  );
});

/// Global [SocketService] instance wired to the availability notifier.
/// Created once, lives for the entire app session (not autoDispose).
final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();

  Future<void> requestVisibleCreatorHydration() async {
    final ids = ref
        .read(creatorAvailabilityProvider)
        .keys
        .where((uid) => uid.isNotEmpty)
        .toList(growable: false);
    if (ids.isNotEmpty) {
      service.requestAvailability(ids);
    }
  }

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
    unawaited(requestVisibleCreatorHydration());
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
  service.onReconnected = () {
    unawaited(requestVisibleCreatorHydration());
  };
  service.refreshSocketAuthToken = () async {
    final notifier = ref.read(authProvider.notifier);
    final refreshed = await notifier.refreshAuthToken();
    if (!refreshed) return null;
    final firebaseUser = ref.read(authProvider).firebaseUser;
    return firebaseUser?.getIdToken();
  };

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
      (creatorId, status, {int? version, int? updatedAt, creatorSummary}) {
        service.trackCreatorForPresence(creatorId);
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
    final coinsRaw = data['coins'] ?? data['newCoinsBalance'];
    if (coinsRaw != null) {
      final coins = (coinsRaw as num?)?.toInt();
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

  void handleMomentsSocketIfEnabled(
    String event,
    Map<String, dynamic> data,
  ) {
    if (!ref.read(appFeaturesProvider).momentsEnabled) return;
    handleMomentsSocketEvent(ref, event, data);
  }

  service.onMomentUploaded = (data) {
    handleMomentsSocketIfEnabled('moment:uploaded', data);
  };
  service.onStoryUploaded = (data) {
    handleMomentsSocketIfEnabled('story:uploaded', data);
  };
  service.onMomentPurchased = (data) {
    handleMomentsSocketIfEnabled('moment:purchased', data);
  };
  service.onMomentPurchaseCount = (data) {
    handleMomentsSocketIfEnabled('moment:purchase_count', data);
  };
  service.onCreatorFollowed = (data) {
    handleMomentsSocketIfEnabled('creator:followed', data);
  };
  service.onMediaReady = (data) {
    handleMomentsSocketIfEnabled('media:ready', data);
  };

  service.onVipCallQueued = (data) {
    if (!ref.read(appFeaturesProvider).vipEnabled) return;
    debugPrint('👑 [SOCKET→PROVIDER] vip:call:queued position=${data['position']}');
    ref.read(vipCallQueueProvider.notifier).onQueued(data);
  };

  service.onVipCallDequeued = (data) {
    if (!ref.read(appFeaturesProvider).vipEnabled) return;
    debugPrint('👑 [SOCKET→PROVIDER] vip:call:dequeued');
    ref.read(vipCallQueueProvider.notifier).onDequeued(data);
  };

  service.onVipCallReadyToRing = (data) {
    if (!ref.read(appFeaturesProvider).vipEnabled) return;
    final creatorId = data['creatorId']?.toString();
    final creatorFirebaseUid = data['creatorFirebaseUid']?.toString();
    if (creatorFirebaseUid != null && creatorId != null) {
      ref.read(vipCallQueueProvider.notifier).requestReadyToRing(
            creatorId: creatorId,
            creatorFirebaseUid: creatorFirebaseUid,
          );
    }
  };

  ref.onDispose(() {
    service.disconnect();
  });

  return service;
});
