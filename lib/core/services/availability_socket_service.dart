import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../../features/user/providers/user_availability_provider.dart';
import '../../features/auth/providers/auth_provider.dart';
// 🔥 CRITICAL FIX: Import home provider to update it as well
import '../../features/home/providers/availability_provider.dart' as home_provider;

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

  /// Update the availability state (for internal tracking)
  void setToggleState(bool isOn) {
    _availabilityToggleOn = isOn;
    _persistToggleState(isOn);
    debugPrint('📱 [SOCKET] Availability state updated: $isOn');
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
      
      // 🔥 AUTOMATIC ONLINE: Creators are automatically online when app opens
      // Backend socket handler will also set online on connect
      // This ensures instant online status when socket connects
      if (_isCreator) {
        debugPrint('📤 [SOCKET] Creator connected - automatically emitting online');
        _socket!.emit('creator:online');
        _availabilityToggleOn = true;
        _persistToggleState(true);
        
        // 🔥 CRITICAL: Update creator's own status immediately in BOTH providers
        // Backend will broadcast the status change, but we update locally first
        // for instant UI feedback
        if (_globalContainer != null) {
          try {
            final authState = _globalContainer!.read(authProvider);
            final firebaseUid = authState.firebaseUser?.uid;
            if (firebaseUid != null) {
              // Update provider from availability_socket_service.dart
              _globalContainer!.read(creatorAvailabilityProvider.notifier)
                  .update(firebaseUid, CreatorAvailability.online);
              
              // 🔥 CRITICAL FIX: Also update provider from availability_provider.dart
              // This ensures users see creator as online instantly
              try {
                _globalContainer!.read(home_provider.creatorAvailabilityProvider.notifier)
                    .updateSingle(firebaseUid, 'online');
                debugPrint('📡 [SOCKET] Updated both providers: creator own status to online immediately');
              } catch (e) {
                debugPrint('⚠️  [SOCKET] Failed to update home provider: $e');
              }
            }
          } catch (e) {
            debugPrint('⚠️  [SOCKET] Failed to update creator own status: $e');
          }
        }
      }
      
      // 🔥 AUTOMATIC ONLINE: Regular users are automatically online when app opens
      // Backend socket handler will also set online on connect
      // This ensures instant online status when socket connects
      if (!_isCreator && _authToken != null) {
        debugPrint('📤 [SOCKET] User connected - automatically emitting online');
        _socket!.emit('user:online');
      }
      
      // Note: Availability is fetched on-demand via requestAvailability()
      // when the home screen loads, not on connect
    });

    _socket!.onDisconnect((reason) {
      _isConnected = false;
      debugPrint('🔌 [SOCKET] Disconnected: $reason');
      
      // 🔥 AUTOMATIC OFFLINE: Creators are automatically offline when app closes
      // Backend socket handler will also set offline on disconnect
      // This ensures instant offline status when socket disconnects
      if (_isCreator) {
        debugPrint('📤 [SOCKET] Creator disconnected - updating status to offline');
        // Note: Socket is already disconnected, so we can't emit
        // Backend will handle this automatically via disconnect event
        _availabilityToggleOn = false;
        _persistToggleState(false);
        
        // 🔥 CRITICAL: Update creator's own status immediately in BOTH providers
        // Backend will broadcast the status change, but we update locally first
        // for instant UI feedback
        if (_globalContainer != null) {
          try {
            final authState = _globalContainer!.read(authProvider);
            final firebaseUid = authState.firebaseUser?.uid;
            if (firebaseUid != null) {
              // Update provider from availability_socket_service.dart
              _globalContainer!.read(creatorAvailabilityProvider.notifier)
                  .update(firebaseUid, CreatorAvailability.busy);
              
              // 🔥 CRITICAL FIX: Also update provider from availability_provider.dart
              // This ensures users see creator as busy instantly
              try {
                _globalContainer!.read(home_provider.creatorAvailabilityProvider.notifier)
                    .updateSingle(firebaseUid, 'busy');
                debugPrint('📡 [SOCKET] Updated both providers: creator own status to offline immediately');
              } catch (e) {
                debugPrint('⚠️  [SOCKET] Failed to update home provider: $e');
              }
            }
          } catch (e) {
            debugPrint('⚠️  [SOCKET] Failed to update creator own status: $e');
          }
        }
      }
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

    // User availability events
    _socket!.on('user:status', (data) {
      _handleUserStatus(data);
    });

    _socket!.on('user:availability:batch', (data) {
      _handleUserAvailabilityBatch(data);
    });

    // Connect
    _socket!.connect();
  }

  /// Handle single creator status update
  /// 🔥 CRITICAL: Updates BOTH providers to ensure consistency
  /// - Updates provider from availability_socket_service.dart (for creator's own status)
  /// - Updates provider from availability_provider.dart (for user homepage)
  void _handleCreatorStatus(dynamic data) {
    if (_globalContainer == null) {
      debugPrint('⚠️  [SOCKET] _globalContainer is null, cannot update providers. Event will be handled by SocketService.');
      return;
    }
    
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
      
      // Update provider from availability_socket_service.dart (for creator's own status)
      try {
        _globalContainer!.read(creatorAvailabilityProvider.notifier).update(creatorId, status);
        debugPrint('📡 [AVAILABILITY SOCKET] Updated provider 1 (socket service): $creatorId → $statusStr');
      } catch (e) {
        debugPrint('⚠️  [AVAILABILITY SOCKET] Could not update provider 1: $e');
      }
      
      // 🔥 CRITICAL FIX: Also update provider from availability_provider.dart (for user homepage)
      // This ensures users see status changes instantly without manual reload
      try {
        _globalContainer!.read(home_provider.creatorAvailabilityProvider.notifier)
            .updateSingle(creatorId, statusStr);
        debugPrint('📡 [AVAILABILITY SOCKET] Updated provider 2 (home provider): $creatorId → $statusStr');
      } catch (e) {
        debugPrint('⚠️  [AVAILABILITY SOCKET] Could not update home provider: $e');
        // This is non-critical - SocketService will also handle the event if connected
      }
    } catch (e) {
      debugPrint('❌ [SOCKET] Error handling creator:status: $e');
    }
  }

  /// Handle batch availability response
  /// 🔥 CRITICAL: Updates BOTH providers to ensure consistency
  void _handleAvailabilityBatch(dynamic data) {
    if (_globalContainer == null) {
      debugPrint('⚠️  [SOCKET] _globalContainer is null, cannot update providers. Event will be handled by SocketService.');
      return;
    }
    
    try {
      if (data is! Map) {
        debugPrint('⚠️  [SOCKET] Invalid availability:batch data: $data');
        return;
      }
      
      // Convert to Map<String, String> for both providers
      final batchMap = <String, String>{};
      final batchMapEnum = <String, CreatorAvailability>{};
      data.forEach((key, value) {
        if (key is String && value is String) {
          batchMap[key] = value;
          final status = value == 'online'
              ? CreatorAvailability.online
              : CreatorAvailability.busy;
          batchMapEnum[key] = status;
        }
      });
      
      // Update provider from availability_socket_service.dart
      try {
        _globalContainer!.read(creatorAvailabilityProvider.notifier).updateAll(batchMapEnum);
        debugPrint('📋 [AVAILABILITY SOCKET] Updated provider 1 with batch: ${batchMap.length} creator(s)');
      } catch (e) {
        debugPrint('⚠️  [AVAILABILITY SOCKET] Could not update provider 1 batch: $e');
      }
      
      // 🔥 CRITICAL FIX: Also update provider from availability_provider.dart
      try {
        _globalContainer!.read(home_provider.creatorAvailabilityProvider.notifier)
            .updateBatch(batchMap);
        debugPrint('📋 [AVAILABILITY SOCKET] Updated provider 2 with batch: ${batchMap.length} creator(s)');
      } catch (e) {
        debugPrint('⚠️  [AVAILABILITY SOCKET] Could not update home provider batch: $e');
      }
      
      debugPrint('📋 [SOCKET] Batch availability received: ${data.length} creator(s)');
    } catch (e) {
      debugPrint('❌ [SOCKET] Error handling availability:batch: $e');
    }
  }

  /// Handle single user status update
  void _handleUserStatus(dynamic data) {
    if (_globalContainer == null) return;
    
    try {
      final firebaseUid = data['firebaseUid'] as String?;
      final statusStr = data['status'] as String?;
      
      if (firebaseUid == null || statusStr == null) {
        debugPrint('⚠️  [SOCKET] Invalid user:status data: $data');
        return;
      }
      
      // Import user availability provider
      final userAvailabilityNotifier = _globalContainer!.read(
        userAvailabilityProvider.notifier,
      );
      
      final status = statusStr == 'online'
          ? UserAvailability.online
          : UserAvailability.offline;
      
      userAvailabilityNotifier.update(firebaseUid, status);
    } catch (e) {
      debugPrint('❌ [SOCKET] Error handling user:status: $e');
    }
  }

  /// Handle batch user availability response
  void _handleUserAvailabilityBatch(dynamic data) {
    if (_globalContainer == null) return;
    
    try {
      if (data is! Map) {
        debugPrint('⚠️  [SOCKET] Invalid user:availability:batch data: $data');
        return;
      }
      
      // Import user availability provider
      final userAvailabilityNotifier = _globalContainer!.read(
        userAvailabilityProvider.notifier,
      );
      
      final batchData = <String, String>{};
      data.forEach((key, value) {
        if (key is String && value is String) {
          batchData[key] = value;
        }
      });
      
      userAvailabilityNotifier.updateBatch(batchData);
      debugPrint('📋 [SOCKET] Batch user availability received: ${batchData.length} user(s)');
    } catch (e) {
      debugPrint('❌ [SOCKET] Error handling user:availability:batch: $e');
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
    
    // Emit offline before disconnecting (if creator or user)
    if (_isConnected && _socket != null) {
      if (_isCreator) {
        _socket!.emit('creator:offline');
      } else if (_authToken != null) {
        // Regular user
        _socket!.emit('user:offline');
      }
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
