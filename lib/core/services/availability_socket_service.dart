import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'sentry_service.dart';
import '../../features/user/providers/user_availability_provider.dart';
// 🔥 CRITICAL FIX: Import home provider to update it as well
import '../../features/home/providers/availability_provider.dart' as home_provider;

typedef CreatorAvailability = home_provider.CreatorAvailability;

/// Compatibility read-only mirror. Runtime authority is home provider.
final creatorAvailabilityProvider = Provider<Map<String, CreatorAvailability>>((ref) {
  return ref.watch(home_provider.creatorAvailabilityProvider);
});

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
      SentryService.addBreadcrumb(
        category: 'socket',
        message: 'availability.connect',
      );
      
      // 🔥 AUTOMATIC ONLINE: Creators are automatically online when app opens
      // Backend socket handler will also set online on connect
      // This ensures instant online status when socket connects
      if (_isCreator) {
        debugPrint('📤 [SOCKET] Creator connected - automatically emitting online');
        _socket!.emit('creator:online');
        _availabilityToggleOn = true;
        _persistToggleState(true);
        
        // Do not locally force-write presence state. Wait for backend versioned
        // creator:status so the authoritative reducer keeps strict monotonic merges.
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
      SentryService.addBreadcrumb(
        category: 'socket',
        message: 'availability.disconnect',
      );
      
      // IMPORTANT:
      // Socket disconnects can be transient (wifi switch, background jitter, etc.).
      // Do NOT immediately flip the creator to offline locally, because the backend
      // is authoritative and may still consider the creator online (or will restore
      // them quickly on reconnect). Immediate local offline causes the creator
      // homepage to show "offline" while user homepage still shows "online".
      if (_isCreator) {
        debugPrint(
          '📤 [SOCKET] Creator disconnected — keeping last known status (await reconnect / backend status)',
        );
        // Keep creators logically "available" while app is running; reconnect path
        // will emit creator:online again on connect.
        _availabilityToggleOn = true;
        _persistToggleState(true);
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
    _socket!.on('availability:batch:v2', (data) {
      _handleAvailabilityBatchV2(data);
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

  /// Handle single creator status update (version-gated authority path).
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

      final version = (data is Map ? data['version'] as num? : null)?.toInt();
      try {
        _globalContainer!.read(home_provider.creatorAvailabilityProvider.notifier)
            .updateSingle(creatorId, statusStr, version: version);
        debugPrint('📡 [AVAILABILITY SOCKET] Updated home provider: $creatorId → $statusStr (v=$version)');
      } catch (e) {
        debugPrint('⚠️  [AVAILABILITY SOCKET] Could not update home provider: $e');
      }
    } catch (e) {
      debugPrint('❌ [SOCKET] Error handling creator:status: $e');
    }
  }

  /// Ignore unversioned batch updates to preserve strict monotonic merges.
  void _handleAvailabilityBatch(dynamic data) {
    debugPrint('⚠️  [SOCKET] Ignoring unversioned availability:batch event');
  }

  void _handleAvailabilityBatchV2(dynamic data) {
    if (_globalContainer == null) return;
    try {
      if (data is! Map) {
        debugPrint('⚠️  [SOCKET] Invalid availability:batch:v2 data: $data');
        return;
      }
      final payload = <String, Map<String, dynamic>>{};
      data.forEach((key, value) {
        if (key == null || value is! Map) return;
        payload[key.toString()] = Map<String, dynamic>.from(
          value.map((k, v) => MapEntry(k.toString(), v)),
        );
      });
      _globalContainer!.read(home_provider.creatorAvailabilityProvider.notifier).updateBatchV2(payload);
      debugPrint('📋 [SOCKET] Processed availability:batch:v2 for ${payload.length} creator(s)');
    } catch (e) {
      debugPrint('❌ [SOCKET] Error handling availability:batch:v2: $e');
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
/// Returns CreatorAvailability.offline if not found (safe default)
final creatorStatusProvider = Provider.family<CreatorAvailability, String?>((ref, creatorId) {
  if (creatorId == null || creatorId.isEmpty) {
    return CreatorAvailability.offline;
  }

  return ref.watch(
    creatorAvailabilityProvider.select(
      (map) => map[creatorId] ?? CreatorAvailability.offline,
    ),
  );
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
