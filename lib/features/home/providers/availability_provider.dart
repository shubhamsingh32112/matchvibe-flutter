import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/socket_service.dart';
import '../../creator/providers/creator_dashboard_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/providers/wallet_pricing_provider.dart';
// 🔥 CRITICAL FIX: Import socket service provider to update creator's own status
import '../../../core/services/availability_socket_service.dart' as socket_service;

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
    final newAvailability = status == 'online' 
        ? CreatorAvailability.online 
        : CreatorAvailability.busy;
    
    // Only update if status actually changed (prevents unnecessary rebuilds)
    if (newState[creatorId] != newAvailability) {
      newState[creatorId] = newAvailability;
      state = newState;
      debugPrint('📡 [AVAILABILITY] Updated creator status: $creatorId → $status');
    } else {
      debugPrint('📡 [AVAILABILITY] Creator status unchanged: $creatorId → $status (skipping update)');
    }
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

  /// Clear all availability (e.g., on disconnect / logout).
  void clear() {
    state = {};
    debugPrint('📡 [AVAILABILITY] Cleared all creator availability');
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
      ref.read(socket_service.creatorAvailabilityProvider.notifier).updateAll(batchMap);
      debugPrint('✅ [SOCKET→PROVIDER] Successfully updated socket service provider with batch');
    } catch (e) {
      debugPrint('⚠️  [SOCKET→PROVIDER] Could not update socket service provider batch: $e');
      // Non-critical - AvailabilitySocketService will also handle the event if connected
    }
  };
  service.onCreatorStatus = (creatorId, status) {
    debugPrint('📡 [SOCKET→PROVIDER] Received creator:status event: $creatorId → $status');
    try {
      // Update provider from availability_provider.dart (for user homepage)
      ref.read(creatorAvailabilityProvider.notifier).updateSingle(creatorId, status);
      debugPrint('✅ [SOCKET→PROVIDER] Successfully updated home provider for $creatorId');
      
      // 🔥 CRITICAL FIX: Also update provider from availability_socket_service.dart
      // This ensures creator's own status updates instantly when SocketService receives events
      // This is especially important if AvailabilitySocketService is not connected or initialized
      try {
        final statusEnum = status == 'online'
            ? socket_service.CreatorAvailability.online
            : socket_service.CreatorAvailability.busy;
        ref.read(socket_service.creatorAvailabilityProvider.notifier)
            .update(creatorId, statusEnum);
        debugPrint('✅ [SOCKET→PROVIDER] Successfully updated socket service provider for $creatorId');
      } catch (e) {
        debugPrint('⚠️  [SOCKET→PROVIDER] Could not update socket service provider: $e');
        // Non-critical - AvailabilitySocketService will also handle the event if connected
      }
    } catch (e) {
      debugPrint('❌ [SOCKET→PROVIDER] Failed to update provider: $e');
    }
  };

  // ── Creator data sync: invalidate dashboard + refresh user on data_updated ──
  service.onCreatorDataUpdated = (data) {
    debugPrint('📊 [SOCKET→PROVIDER] creator:data_updated received, reason: ${data['reason']}');
    // Invalidate the central dashboard provider so all watchers get fresh data
    // This updates earnings, tasks, and stats (but NOT coins - handled separately)
    ref.invalidate(creatorDashboardProvider);
    
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
      debugPrint('⚠️  [SOCKET→PROVIDER] coins_updated missing coins, falling back to refresh');
      ref.read(authProvider.notifier).refreshUser();
    }
  };

  service.onWalletPricingUpdated = (data) {
    debugPrint('💳 [SOCKET→PROVIDER] wallet_pricing_updated received: $data');
    ref.invalidate(walletPricingProvider);
  };

  ref.onDispose(() {
    service.disconnect();
  });

  return service;
});
