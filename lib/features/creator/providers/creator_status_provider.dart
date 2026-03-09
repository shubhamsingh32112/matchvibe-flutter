import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/availability_socket_service.dart';
import '../../auth/providers/auth_provider.dart';

enum CreatorStatus {
  online,
  offline,
}

/// Provider to manage creator online/offline status
/// 
/// 🔥 AUTOMATIC STATUS: Status is automatically managed by socket connection
/// - When creator opens app → socket connects → automatically online
/// - When creator closes app → socket disconnects → automatically offline
/// 
/// This provider is READ-ONLY and reflects the backend-authoritative status.
/// It listens to socket events for real-time updates of the creator's own status.
/// No manual toggle is available - status is automatic based on app lifecycle.
/// 
/// Usage example:
/// ```dart
/// // Watch the status
/// final status = ref.watch(creatorStatusProvider);
/// final isOnline = status == CreatorStatus.online;
/// 
/// // Check if online
/// final isOnline = ref.read(creatorStatusProvider.notifier).isOnline;
/// ```
final creatorStatusProvider = StateNotifierProvider<CreatorStatusNotifier, CreatorStatus>((ref) {
  return CreatorStatusNotifier(ref);
});

class CreatorStatusNotifier extends StateNotifier<CreatorStatus> {
  final Ref _ref;
  
  CreatorStatusNotifier(this._ref) : super(CreatorStatus.offline) {
    _initializeStatus();
    _listenToSocketEvents();
  }

  void _initializeStatus() {
    final authState = _ref.read(authProvider);
    final user = authState.user;
    final isCreator = user != null &&
        (user.role == 'creator' || user.role == 'admin');

    if (isCreator) {
      final socketService = AvailabilitySocketService.instance;
      final firebaseUid = authState.firebaseUser?.uid;
      
      // Check both socket connection state and availability provider
      // This ensures we reflect the actual backend status
      if (socketService.isConnected && firebaseUid != null) {
        // Check availability provider for the creator's own status
        final availabilityMap = _ref.read(creatorAvailabilityProvider);
        final ownAvailability = availabilityMap[firebaseUid];
        
        // 🔥 CRITICAL FIX: If socket is connected, show online immediately
        // Backend will broadcast status shortly, but we show online instantly for better UX
        if (ownAvailability == CreatorAvailability.online) {
          state = CreatorStatus.online;
        } else {
          // Socket is connected but status not in provider yet - show online immediately
          // Backend will broadcast status and update provider shortly
          state = CreatorStatus.online;
          debugPrint('📡 [CREATOR STATUS] Initialized as online (socket connected, status pending)');
        }
      } else {
        // Socket not connected - show offline
        state = CreatorStatus.offline;
        debugPrint('📡 [CREATOR STATUS] Initialized as offline (socket not connected)');
      }
    } else {
      state = CreatorStatus.offline;
    }
  }

  /// Listen to socket events for real-time status updates
  /// This ensures the creator's own status updates instantly when backend broadcasts changes
  void _listenToSocketEvents() {
    final authState = _ref.read(authProvider);
    final user = authState.user;
    final isCreator = user != null &&
        (user.role == 'creator' || user.role == 'admin');

    if (!isCreator) return;

    final firebaseUid = authState.firebaseUser?.uid;
    if (firebaseUid == null) return;

    // Listen to availability provider for the creator's own Firebase UID
    // This will update whenever the backend broadcasts a status change
    _ref.listen<Map<String, CreatorAvailability>>(
      creatorAvailabilityProvider,
      (previous, next) {
        final ownAvailability = next[firebaseUid];
        if (ownAvailability != null) {
          final newStatus = ownAvailability == CreatorAvailability.online
              ? CreatorStatus.online
              : CreatorStatus.offline;
          
          if (state != newStatus) {
            state = newStatus;
            debugPrint('📡 [CREATOR STATUS] Updated from socket event: ${newStatus == CreatorStatus.online ? "online" : "offline"}');
          }
        } else {
          // If not in map, check socket connection state
          final socketService = AvailabilitySocketService.instance;
          if (socketService.isConnected) {
            // Socket is connected but status not in map yet - assume online
            // Backend will broadcast status shortly
            if (state != CreatorStatus.online) {
              state = CreatorStatus.online;
              debugPrint('📡 [CREATOR STATUS] Updated from socket connection: online');
            }
          } else {
            // Socket disconnected - definitely offline
            if (state != CreatorStatus.offline) {
              state = CreatorStatus.offline;
              debugPrint('📡 [CREATOR STATUS] Updated from socket disconnection: offline');
            }
          }
        }
      },
    );
  }

  /// Update status based on socket connection state
  /// Called automatically when socket connects/disconnects
  void updateFromSocketConnection(bool isConnected) {
    final authState = _ref.read(authProvider);
    final user = authState.user;
    final isCreator = user != null &&
        (user.role == 'creator' || user.role == 'admin');

    if (isCreator) {
      final firebaseUid = authState.firebaseUser?.uid;
      if (firebaseUid != null) {
        // Check availability provider first (backend-authoritative)
        final availabilityMap = _ref.read(creatorAvailabilityProvider);
        final ownAvailability = availabilityMap[firebaseUid];
        
        if (isConnected) {
          // Socket connected - check backend status or default to online
          if (ownAvailability == CreatorAvailability.online) {
            state = CreatorStatus.online;
          } else {
            // Backend will set online shortly, but show online immediately
            state = CreatorStatus.online;
          }
        } else {
          // Socket disconnected - definitely offline
          state = CreatorStatus.offline;
        }
      } else {
        state = isConnected ? CreatorStatus.online : CreatorStatus.offline;
      }
      debugPrint('📡 [CREATOR STATUS] Updated from socket connection: ${isConnected ? "online" : "offline"}');
    }
  }

  bool get isOnline => state == CreatorStatus.online;
}
