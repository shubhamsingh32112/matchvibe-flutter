import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/availability_socket_service.dart';
import '../../auth/providers/auth_provider.dart';

enum CreatorStatus {
  online,
  offline,
}

/// Provider to manage creator online/offline status
/// 
/// 🔥 BACKEND-AUTHORITATIVE: Uses Socket.IO to emit status changes
/// Stream Chat is NO LONGER used for availability.
/// 
/// This provider is accessible everywhere in the app via Riverpod.
/// 
/// Usage example:
/// ```dart
/// // Watch the status
/// final status = ref.watch(creatorStatusProvider);
/// final isOnline = status == CreatorStatus.online;
/// 
/// // Toggle status
/// ref.read(creatorStatusProvider.notifier).toggleStatus();
/// 
/// // Set specific status
/// ref.read(creatorStatusProvider.notifier).setStatus(CreatorStatus.online);
/// 
/// // Check if online
/// final isOnline = ref.read(creatorStatusProvider.notifier).isOnline;
/// ```
final creatorStatusProvider = StateNotifierProvider<CreatorStatusNotifier, CreatorStatus>((ref) {
  return CreatorStatusNotifier(ref);
});

class CreatorStatusNotifier extends StateNotifier<CreatorStatus> {
  static const String _statusKey = 'creator_available';
  final Ref _ref;
  final ApiClient _apiClient = ApiClient();
  
  CreatorStatusNotifier(this._ref) : super(CreatorStatus.offline) {
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authState = _ref.read(authProvider);
      final user = authState.user;
      final isCreator = user != null &&
          (user.role == 'creator' || user.role == 'admin');

      // Product requirement: creators are online whenever they open the app.
      final isAvailable = isCreator ? true : (prefs.getBool(_statusKey) ?? false);
      if (isCreator) {
        await prefs.setBool(_statusKey, true);
      }
      state = isAvailable ? CreatorStatus.online : CreatorStatus.offline;
      
      // 🔥 Sync loaded status via Socket.IO
      // Note: Socket connection must be initialized first (happens in app startup)
      if (user != null && (user.role == 'creator' || user.role == 'admin')) {
        // 🔥 FIX 1 & 3: Use new API without creatorId (server uses authenticated ID)
        _emitSocketStatus(isAvailable);
      }
    } catch (e) {
      debugPrint('⚠️  [CREATOR STATUS] Error loading status: $e');
      state = CreatorStatus.offline;
    }
  }

  /// 🔥 EMIT STATUS VIA SOCKET.IO (REPLACES STREAM CHAT)
  /// This is the AUTHORITATIVE method for updating creator availability
  /// 
  /// 🔥 FIX 1: No creatorId parameter - server uses authenticated ID from token
  /// 🔥 FIX 3: Updates toggle state for reconnect logic
  void _emitSocketStatus(bool isOnline) {
    final socketService = AvailabilitySocketService.instance;
    
    // 🔥 FIX 3: Update toggle state so reconnect knows what to emit
    socketService.setToggleState(isOnline);
    
    if (isOnline) {
      socketService.setOnline();
    } else {
      socketService.setOffline();
    }
    
    debugPrint('📤 [CREATOR STATUS] Socket emitted: ${isOnline ? "online" : "offline"}');
  }

  Future<void> setStatus(CreatorStatus status, {bool syncToBackend = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAvailable = status == CreatorStatus.online;
      await prefs.setBool(_statusKey, isAvailable);
      state = status;
      
      final authState = _ref.read(authProvider);
      final user = authState.user;
      
      // Only creators can set their status
      if (user == null || (user.role != 'creator' && user.role != 'admin')) {
        return;
      }
      
      // 🔥 CRITICAL: Emit status via Socket.IO (REPLACES STREAM CHAT)
      // This is the SINGLE SOURCE OF TRUTH for availability
      // 🔥 FIX 1: No Firebase UID needed - server uses authenticated ID from token
      _emitSocketStatus(isAvailable);
      
      // Also sync to backend (for API queries and legacy support)
      if (syncToBackend) {
        try {
          await _apiClient.patch('/creator/status', data: {
            'isOnline': isAvailable,
          });
          debugPrint('✅ [CREATOR STATUS] Backend synced: ${isAvailable ? "available" : "unavailable"}');
        } catch (e) {
          debugPrint('⚠️  [CREATOR STATUS] Failed to sync to backend: $e');
          // Don't fail the status update if backend sync fails
        }
      }
      
      // Note: No longer need to invalidate homeFeedProvider
      // Socket.IO pushes updates to all clients automatically
    } catch (e) {
      debugPrint('❌ [CREATOR STATUS] Error saving creator status: $e');
    }
  }

  void toggleStatus() {
    final newStatus = state == CreatorStatus.online 
        ? CreatorStatus.offline 
        : CreatorStatus.online;
    setStatus(newStatus);
  }

  bool get isOnline => state == CreatorStatus.online;
}
