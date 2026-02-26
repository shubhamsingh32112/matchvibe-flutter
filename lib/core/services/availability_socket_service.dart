import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Creator availability status enum
/// 
/// Only two states:
/// - online: creator is available for calls
/// - busy: creator is on a call, offline, or unavailable
enum CreatorAvailability {
  online,
  busy,
}

/// 🔥 BACKEND-AUTHORITATIVE Availability Provider
/// 
/// This replaces ALL Stream Chat presence logic.
/// 
/// Status is pushed from backend via Socket.IO.
/// Missing/unknown creators are ALWAYS 'busy'.
final creatorAvailabilityProvider = StateNotifierProvider<
    CreatorAvailabilityNotifier, Map<String, CreatorAvailability>>(
  (ref) => CreatorAvailabilityNotifier(),
);

/// Notifier that holds the availability map
class CreatorAvailabilityNotifier
    extends StateNotifier<Map<String, CreatorAvailability>> {
  CreatorAvailabilityNotifier() : super({});

  /// Guard: prevents API re-seeding from overwriting newer socket data.
  /// Set to true after the first API seed; reset only on clear() (logout).
  bool _hasSeeded = false;

  /// Seed availability from an API response.
  /// Only runs ONCE – subsequent calls (e.g. after creatorsProvider invalidation)
  /// are no-ops so that fresher socket data is never overwritten.
  void seedFromApi(Map<String, CreatorAvailability> apiData) {
    if (_hasSeeded) {
      debugPrint('📡 [AVAILABILITY] Skipping API re-seed (already seeded, socket is authoritative)');
      return;
    }
    _hasSeeded = true;
    state = {...state, ...apiData};
    debugPrint('📡 [AVAILABILITY] Seeded from API: ${apiData.length} creator(s)');
  }

  /// Update a single creator's availability.
  /// Called by socket handlers – ALWAYS overwrites (socket is authoritative).
  void update(String creatorId, CreatorAvailability status) {
    state = {...state, creatorId: status};
    debugPrint('📡 [AVAILABILITY] Updated: $creatorId → $status');
  }

  /// Bulk update from availability:all event
  void updateAll(Map<String, CreatorAvailability> newState) {
    state = newState;
    debugPrint('📡 [AVAILABILITY] Bulk update: ${newState.length} creator(s)');
  }

  /// Get availability for a specific creator
  /// Returns 'busy' if not found (safe default)
  CreatorAvailability get(String creatorId) {
    return state[creatorId] ?? CreatorAvailability.busy;
  }

  /// Clear all availability (e.g., on disconnect / logout).
  /// Resets the hasSeeded flag so the next API fetch can seed again.
  void clear() {
    _hasSeeded = false;
    state = {};
    debugPrint('📡 [AVAILABILITY] Cleared all (hasSeeded reset)');
  }
}

// Global container reference for socket callbacks
ProviderContainer? _globalContainer;

/// Set the global container (call once in main.dart or app startup)
void setGlobalProviderContainer(ProviderContainer container) {
  _globalContainer = container;
}

/// 🔥 Socket.IO Availability Service
/// 
/// Connects to backend Socket.IO server for real-time availability updates.
/// 
/// 🔥 FIX 1: Socket connections are AUTHENTICATED
/// - Sends Firebase token in handshake
/// - Backend verifies token and extracts creatorId
/// 
/// 🔥 FIX 3: Reconnect logic
/// - On reconnect, re-emits online if availability toggle is ON
/// 
/// 🔥 FIX 5: Lifecycle events
/// - Handles logout, app killed scenarios
class AvailabilitySocketService {
  static AvailabilitySocketService? _instance;
  IO.Socket? _socket;
  String? _authToken; // Firebase ID token
  bool _isCreator = false;
  bool _isConnected = false;
  bool _availabilityToggleOn = false; // Creator's availability toggle state

  // SharedPreferences key for availability toggle
  static const String _toggleKey = 'creator_available';

  // Singleton
  static AvailabilitySocketService get instance {
    _instance ??= AvailabilitySocketService._();
    return _instance!;
  }

  AvailabilitySocketService._();

  /// Initialize the socket connection
  /// 🔥 FIX 1: Requires auth token for creators (server verifies and extracts creatorId)
  /// 🔥 FIX 3: Loads toggle state for reconnect logic
  void init(
    BuildContext context, {
    required String? authToken,
    String? creatorId, // Not used anymore - server extracts from token
    bool isCreator = false,
  }) {
    // Get the ProviderContainer from context
    try {
      _globalContainer = ProviderScope.containerOf(context);
    } catch (e) {
      debugPrint('⚠️  [SOCKET] Could not get ProviderContainer from context: $e');
    }
    
    _authToken = authToken;
    _isCreator = isCreator;
    
    // Product requirement: creators are always online while app is running.
    if (isCreator) {
      _availabilityToggleOn = true;
      _persistToggleState(true);
    }
    
    _connect();
  }

  /// Persist the availability toggle state for app restarts.
  Future<void> _persistToggleState(bool isOn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_toggleKey, isOn);
      debugPrint('📱 [SOCKET] Persisted toggle state: $isOn');
    } catch (e) {
      debugPrint('⚠️  [SOCKET] Failed to persist toggle state: $e');
    }
  }

  /// 🔥 FIX 3: Update the toggle state (called by creator_status_provider)
  void setToggleState(bool isOn) {
    _availabilityToggleOn = isOn;
    _persistToggleState(isOn);
    debugPrint('📱 [SOCKET] Toggle state updated: $isOn');
  }

  /// Connect to Socket.IO server
  void _connect() {
    // 🔥 FIX 3: Guard against duplicate connections (idempotent)
    if (_socket != null && _isConnected) {
      debugPrint('⚠️  [SOCKET] Already connected, skipping');
      return;
    }
    
    // If socket exists but not connected, dispose first
    if (_socket != null) {
      debugPrint('🔄 [SOCKET] Existing socket found, disposing before reconnect');
      _socket!.dispose();
      _socket = null;
    }

    final socketUrl = AppConstants.socketUrl;
    debugPrint('🔌 [SOCKET] Connecting to $socketUrl...');

    // 🔥 FIX 1: Build options with authentication
    // 🔥 CRITICAL: WebSocket ONLY - no polling fallback
    final optionsBuilder = IO.OptionBuilder()
        .setTransports(['websocket']) // 🔥 ONLY websocket - NO polling
        .disableAutoConnect() // We'll connect manually
        .enableReconnection()
        .setReconnectionAttempts(10)
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(5000);
    
    // Add auth token if available
    if (_authToken != null) {
      optionsBuilder.setAuth({'token': _authToken});
      debugPrint('🔐 [SOCKET] Auth token set for handshake');
    }

    _socket = IO.io(socketUrl, optionsBuilder.build());

    // Connection events
    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('✅ [SOCKET] Connected to $socketUrl');
      
      // 🔥 FIX 3: Re-emit online if creator and toggle is ON
      if (_isCreator && _availabilityToggleOn) {
        debugPrint('📤 [SOCKET] Reconnect: emitting online (toggle is ON)');
        _socket!.emit('creator:online');
      } else if (_isCreator) {
        debugPrint('📤 [SOCKET] Reconnect: NOT emitting online (toggle is OFF)');
      }
      
      // Note: Availability is fetched on-demand via requestAvailability()
      // when the home screen loads, not on connect
    });

    _socket!.onDisconnect((reason) {
      _isConnected = false;
      debugPrint('🔌 [SOCKET] Disconnected: $reason');
    });

    _socket!.onConnectError((error) {
      debugPrint('❌ [SOCKET] Connection error: $error');
    });

    _socket!.onError((error) {
      debugPrint('❌ [SOCKET] Error: $error');
    });

    // Availability events
    _socket!.on('creator:status', (data) {
      _handleCreatorStatus(data);
    });

    _socket!.on('availability:batch', (data) {
      _handleAvailabilityBatch(data);
    });

    // Connect
    _socket!.connect();
  }

  /// Handle single creator status update
  void _handleCreatorStatus(dynamic data) {
    if (_globalContainer == null) return;
    
    try {
      final creatorId = data['creatorId'] as String?;
      final statusStr = data['status'] as String?;
      
      if (creatorId == null || statusStr == null) {
        debugPrint('⚠️  [SOCKET] Invalid creator:status data: $data');
        return;
      }
      
      final status = statusStr == 'online'
          ? CreatorAvailability.online
          : CreatorAvailability.busy;
      
      _globalContainer!.read(creatorAvailabilityProvider.notifier).update(creatorId, status);
    } catch (e) {
      debugPrint('❌ [SOCKET] Error handling creator:status: $e');
    }
  }

  /// Handle batch availability response
  void _handleAvailabilityBatch(dynamic data) {
    if (_globalContainer == null) return;
    
    try {
      if (data is! Map) {
        debugPrint('⚠️  [SOCKET] Invalid availability:batch data: $data');
        return;
      }
      
      data.forEach((key, value) {
        if (key is String && value is String) {
          final status = value == 'online'
              ? CreatorAvailability.online
              : CreatorAvailability.busy;
          _globalContainer!.read(creatorAvailabilityProvider.notifier).update(key, status);
        }
      });
      
      debugPrint('📋 [SOCKET] Batch availability received: ${data.length} creator(s)');
    } catch (e) {
      debugPrint('❌ [SOCKET] Error handling availability:batch: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CREATOR-ONLY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Set creator as online (available for calls)
  /// 🔥 FIX 1: No creatorId parameter - server uses authenticated ID
  void setOnline() {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️  [SOCKET] Cannot emit: not connected');
      return;
    }
    
    if (!_isCreator) {
      debugPrint('⚠️  [SOCKET] Cannot emit: not a creator');
      return;
    }
    
    _availabilityToggleOn = true;
    _socket!.emit('creator:online');
    debugPrint('📤 [SOCKET] Emitted creator:online');
  }

  /// Set creator as offline (unavailable)
  /// 🔥 FIX 1: No creatorId parameter - server uses authenticated ID
  void setOffline() {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️  [SOCKET] Cannot emit: not connected');
      return;
    }
    
    if (!_isCreator) {
      debugPrint('⚠️  [SOCKET] Cannot emit: not a creator');
      return;
    }
    
    _availabilityToggleOn = false;
    _socket!.emit('creator:offline');
    debugPrint('📤 [SOCKET] Emitted creator:offline');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Request availability for specific creators (batch)
  /// @param creatorIds - List of Firebase UIDs to get availability for
  void requestAvailability(List<String> creatorIds) {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️  [SOCKET] Cannot request availability: not connected');
      return;
    }
    
    if (creatorIds.isEmpty) {
      debugPrint('⚠️  [SOCKET] Empty creatorIds list, skipping');
      return;
    }
    
    _socket!.emit('availability:get', creatorIds);
    debugPrint('📤 [SOCKET] Requested availability for ${creatorIds.length} creator(s)');
  }

  /// 🔥 FIX 5: Handle logout - disconnect and clear state
  void onLogout() {
    debugPrint('🔌 [SOCKET] Logout - disconnecting...');
    
    // Emit offline before disconnecting (if creator)
    if (_isCreator && _isConnected && _socket != null) {
      _socket!.emit('creator:offline');
    }
    
    dispose();
  }

  /// Disconnect and cleanup
  void dispose() {
    debugPrint('🔌 [SOCKET] Disposing...');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _authToken = null;
    _isCreator = false;
    _availabilityToggleOn = false;
  }

  /// Check if connected
  bool get isConnected => _isConnected;
  
  /// Check if toggle is on
  bool get isToggleOn => _availabilityToggleOn;
}

/// Provider for the socket service
/// Use this to access the service in widgets
final availabilitySocketServiceProvider = Provider<AvailabilitySocketService>((ref) {
  return AvailabilitySocketService.instance;
});

/// 🔥 CONVENIENCE PROVIDER: Get availability for a specific creator
/// 
/// Usage:
/// ```dart
/// final status = ref.watch(creatorStatusProvider(creatorId));
/// ```
/// 
/// Returns CreatorAvailability.busy if not found (safe default)
final creatorStatusProvider = Provider.family<CreatorAvailability, String?>((ref, creatorId) {
  if (creatorId == null) return CreatorAvailability.busy;
  
  final availabilityMap = ref.watch(creatorAvailabilityProvider);
  return availabilityMap[creatorId] ?? CreatorAvailability.busy;
});

/// 🔥 CONVENIENCE PROVIDER: Check if creator is online
/// 
/// Usage:
/// ```dart
/// final isOnline = ref.watch(isCreatorOnlineProvider(creatorId));
/// ```
final isCreatorOnlineProvider = Provider.family<bool, String?>((ref, creatorId) {
  if (creatorId == null) return false;
  
  final status = ref.watch(creatorStatusProvider(creatorId));
  return status == CreatorAvailability.online;
});
