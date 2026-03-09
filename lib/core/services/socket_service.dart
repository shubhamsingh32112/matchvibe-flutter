import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/app_constants.dart';
import '../api/api_client.dart';

/// Singleton Socket.IO service for real-time creator availability
/// and per-second call billing.
///
/// Lifecycle:
///   1. [connect] with a Firebase ID token (auth handshake)
///   2. [requestAvailability] with a list of creator Firebase UIDs
///   3. Listen via callbacks for availability + billing events
///   4. [disconnect] when no longer needed
///
/// The service automatically re-sends the last availability request
/// on reconnect so the UI stays fresh without manual intervention.
///
/// Billing events have a **REST API fallback**: if the socket is not
/// connected, [emitCallStarted] / [emitCallEnded] will call the HTTP
/// endpoint directly so billing is never silently dropped.
class SocketService {
  io.Socket? _socket;
  bool _isConnected = false;
  bool _isConnecting = false;
  List<String> _lastRequestedIds = [];
  Completer<bool>? _connectCompleter;
  // ── Pending billing events (queued when socket is disconnected) ─────────
  Map<String, dynamic>? _pendingCallStarted;
  Map<String, dynamic>? _pendingCallEnded;

  // ── Availability callbacks ──────────────────────────────────────────────
  void Function(Map<String, String>)? onAvailabilityBatch;
  void Function(String creatorId, String status)? onCreatorStatus;

  // ── Billing callbacks ──────────────────────────────────────────────────
  void Function(Map<String, dynamic>)? onBillingStarted;
  void Function(Map<String, dynamic>)? onBillingUpdate;
  void Function(Map<String, dynamic>)? onBillingSettled;
  void Function(Map<String, dynamic>)? onCallForceEnd;
  void Function(Map<String, dynamic>)? onBillingError;

  // ── Creator data sync callback ──────────────────────────────────────────
  /// Fired when the backend emits `creator:data_updated` after:
  /// - Billing settlement (call ended → earnings changed)
  /// - Task reward claim (coins changed)
  void Function(Map<String, dynamic>)? onCreatorDataUpdated;

  // ── Coins updated callback ─────────────────────────────────────────────
  /// Fired when the backend emits `coins_updated` after:
  /// - Buying coins (addCoins)
  /// - Welcome bonus claim
  /// - Any other server-side coin balance change
  void Function(Map<String, dynamic>)? onCoinsUpdated;

  // ── Wallet pricing callback ────────────────────────────────────────────
  /// Fired when admin updates wallet package pricing.
  void Function(Map<String, dynamic>)? onWalletPricingUpdated;

  bool get isConnected => _isConnected;

  // ── Connect ─────────────────────────────────────────────────────────────
  /// Connect to the Socket.IO server.
  ///
  /// 🔥 FIX: If the socket exists but is NOT connected (stale), it is
  /// disposed and re-created.  The old code had `if (_socket != null) return`
  /// which silently skipped reconnection attempts after the first failure.
  void connect(String firebaseToken) {
    // Already connected — nothing to do
    if (_socket != null && _isConnected) {
      debugPrint('🔌 [SOCKET] Already connected, skipping');
      return;
    }

    // Connection in progress — avoid duplicate reconnect storms.
    if (_isConnecting) {
      debugPrint('🔌 [SOCKET] Connection already in progress, skipping');
      return;
    }

    // Socket exists but is NOT connected → dispose stale socket first
    if (_socket != null) {
      debugPrint('🔌 [SOCKET] Stale socket detected (not connected). Disposing and reconnecting...');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
    }

    debugPrint('🔌 [SOCKET] Connecting to ${AppConstants.socketUrl}...');

    _socket = io.io(
      AppConstants.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': firebaseToken})
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('✅ [SOCKET] Connected to ${AppConstants.socketUrl}');
      _isConnected = true;
      _isConnecting = false;
      if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
        _connectCompleter!.complete(true);
      }

      // Re-request availability on (re)connect
      if (_lastRequestedIds.isNotEmpty) {
        debugPrint(
          '📡 [SOCKET] Auto-requesting availability for ${_lastRequestedIds.length} creator(s)',
        );
        _socket!.emit('availability:get', {'creatorIds': _lastRequestedIds});
      }

      // Flush any pending billing events that were queued while disconnected
      _flushPendingBillingEvents();
    });

    _socket!.on('availability:batch', (data) {
      debugPrint('📡 [SOCKET] Received availability:batch');
      if (data is Map) {
        final map = Map<String, String>.from(
          data.map((key, value) => MapEntry(key.toString(), value.toString())),
        );
        onAvailabilityBatch?.call(map);
      }
    });

    _socket!.on('creator:status', (data) {
      debugPrint('📡 [SOCKET] Received creator:status event: $data');
      if (data is Map) {
        final creatorId = data['creatorId']?.toString();
        final status = data['status']?.toString();
        if (creatorId != null && status != null) {
          debugPrint('📡 [SOCKET] Calling onCreatorStatus callback: $creatorId → $status');
          if (onCreatorStatus != null) {
            onCreatorStatus!(creatorId, status);
            debugPrint('✅ [SOCKET] onCreatorStatus callback executed');
          } else {
            debugPrint('⚠️  [SOCKET] onCreatorStatus callback is null! Provider might not be initialized.');
          }
        } else {
          debugPrint('⚠️  [SOCKET] Invalid creator:status data: creatorId=$creatorId, status=$status');
        }
      } else {
        debugPrint('⚠️  [SOCKET] creator:status data is not a Map: ${data.runtimeType}');
      }
    });

    // ── Billing events ──────────────────────────────────────────────────
    _socket!.on('billing:started', (data) {
      debugPrint('💰 [SOCKET] billing:started: $data');
      if (data is Map) {
        onBillingStarted?.call(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('billing:update', (data) {
      if (data is Map) {
        onBillingUpdate?.call(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('billing:settled', (data) {
      debugPrint('💰 [SOCKET] billing:settled: $data');
      if (data is Map) {
        onBillingSettled?.call(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('call:force-end', (data) {
      debugPrint('🚨 [SOCKET] call:force-end: $data');
      if (data is Map) {
        onCallForceEnd?.call(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('billing:error', (data) {
      debugPrint('❌ [SOCKET] billing:error: $data');
      if (data is Map) {
        onBillingError?.call(Map<String, dynamic>.from(data));
      }
    });

    // ── Creator data sync event ──────────────────────────────────────────
    _socket!.on('creator:data_updated', (data) {
      debugPrint('📊 [SOCKET] creator:data_updated: $data');
      if (data is Map) {
        onCreatorDataUpdated?.call(Map<String, dynamic>.from(data));
      }
    });

    // ── Coins updated event ─────────────────────────────────────────────
    _socket!.on('coins_updated', (data) {
      debugPrint('💰 [SOCKET] coins_updated: $data');
      if (data is Map) {
        onCoinsUpdated?.call(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('wallet_pricing_updated', (data) {
      debugPrint('💳 [SOCKET] wallet_pricing_updated: $data');
      if (data is Map) {
        onWalletPricingUpdated?.call(Map<String, dynamic>.from(data));
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('🔌 [SOCKET] Disconnected');
      _isConnected = false;
      _isConnecting = false;
    });

    _socket!.onReconnect((_) {
      debugPrint('🔌 [SOCKET] Reconnected');
      _isConnected = true;

      // Re-hydrate availability after reconnect
      if (_lastRequestedIds.isNotEmpty) {
        _socket!.emit('availability:get', {'creatorIds': _lastRequestedIds});
      }

      // Flush any pending billing events that were queued while disconnected
      _flushPendingBillingEvents();
    });

    _socket!.onConnectError((error) {
      debugPrint('❌ [SOCKET] Connection error: $error');
      _isConnecting = false;
      if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
        _connectCompleter!.complete(false);
      }
    });

    _socket!.onError((error) {
      debugPrint('❌ [SOCKET] Error: $error');
    });

    _isConnecting = true;
    _socket!.connect();
  }

  // ── Ensure Connected ───────────────────────────────────────────────────
  /// Ensure the socket is connected.  If not, (re)connect with the given
  /// [token] and wait up to 2 seconds for the connection to establish.
  ///
  /// Returns `true` if connected, `false` on timeout/failure.
  Future<bool> ensureConnected(String token) async {
    if (_isConnected) return true;

    debugPrint('🔄 [SOCKET] ensureConnected — socket is NOT connected, reconnecting...');
    _connectCompleter ??= Completer<bool>();
    connect(token);

    try {
      final connected = await _connectCompleter!.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
      if (connected) {
        debugPrint('✅ [SOCKET] ensureConnected — connected');
      } else {
        debugPrint(
            '⚠️ [SOCKET] ensureConnected — timed out/failed, continuing without socket');
      }
      return connected;
    } finally {
      _connectCompleter = null;
    }
  }

  // ── Request Availability ────────────────────────────────────────────────
  /// Emit [availability:get] with the given creator Firebase UIDs.
  /// If the socket is not yet connected the IDs are queued and will be
  /// sent automatically when the connection is established.
  void requestAvailability(List<String> creatorIds) {
    if (creatorIds.isEmpty) return;

    _lastRequestedIds = creatorIds;

    if (!_isConnected || _socket == null) {
      debugPrint(
        '⏳ [SOCKET] Not connected yet — availability request queued (${creatorIds.length} IDs)',
      );
      return;
    }

    debugPrint(
      '📡 [SOCKET] Emitting availability:get for ${creatorIds.length} creator(s)',
    );
    _socket!.emit('availability:get', {'creatorIds': creatorIds});
  }

  // ── Billing Emitters ────────────────────────────────────────────────────

  /// Notify the backend that a call has started (triggers billing loop).
  ///
  /// 🔥 FIX: If the socket is not connected, we now call the REST API
  /// directly as a fallback so billing is never silently dropped.
  ///
  /// [userFirebaseUid] - Optional. For creator-initiated calls, specifies the user who pays.
  ///                     For user-initiated calls, this is null and the socket owner pays.
  void emitCallStarted({
    required String callId,
    required String creatorFirebaseUid,
    required String creatorMongoId,
    String? userFirebaseUid,
  }) {
    final data = {
      'callId': callId,
      'creatorFirebaseUid': creatorFirebaseUid,
      'creatorMongoId': creatorMongoId,
      if (userFirebaseUid != null) 'userFirebaseUid': userFirebaseUid,
    };

    if (_socket != null && _isConnected) {
      debugPrint('💰 [SOCKET] Emitting call:started for $callId');
      _socket!.emit('call:started', data);
      _pendingCallStarted = null;
      return;
    }

    // Socket not connected → use REST API fallback
    debugPrint(
        '⚠️ [SOCKET] Cannot emit call:started — not connected. Using REST API fallback for $callId');
    _pendingCallStarted = data;
    _billingViaHttp('call-started', data);
  }

  /// Notify the backend that a call has ended (triggers settlement).
  ///
  /// 🔥 FIX: If the socket is not connected, we now call the REST API
  /// directly as a fallback so settlement is never silently dropped.
  void emitCallEnded({required String callId}) {
    final data = {'callId': callId};

    if (_socket != null && _isConnected) {
      debugPrint('💰 [SOCKET] Emitting call:ended for $callId');
      _socket!.emit('call:ended', data);
      _pendingCallEnded = null;
      return;
    }

    // Socket not connected → use REST API fallback
    debugPrint(
        '⚠️ [SOCKET] Cannot emit call:ended — not connected. Using REST API fallback for $callId');
    _pendingCallEnded = data;
    _billingViaHttp('call-ended', data);
  }

  /// REST API fallback for billing events when the socket is down.
  Future<void> _billingViaHttp(String event, Map<String, dynamic> data) async {
    try {
      debugPrint('🌐 [BILLING HTTP] POST /billing/$event with data: $data');
      final response = await ApiClient().post('/billing/$event', data: data);
      debugPrint('✅ [BILLING HTTP] $event response: ${response.statusCode}');
      // Clear the pending event on success
      if (event == 'call-started') {
        _pendingCallStarted = null;
      } else if (event == 'call-ended') {
        _pendingCallEnded = null;
      }
    } catch (e) {
      debugPrint('❌ [BILLING HTTP] $event failed: $e');
      // Keep the pending event so it can be flushed on socket reconnect
    }
  }

  /// Flush any pending billing events that were queued while disconnected.
  void _flushPendingBillingEvents() {
    if (_socket == null || !_isConnected) return;

    if (_pendingCallStarted != null) {
      debugPrint(
          '💰 [SOCKET] Flushing queued call:started for ${_pendingCallStarted!['callId']}');
      _socket!.emit('call:started', _pendingCallStarted!);
      _pendingCallStarted = null;
    }

    if (_pendingCallEnded != null) {
      debugPrint(
          '💰 [SOCKET] Flushing queued call:ended for ${_pendingCallEnded!['callId']}');
      _socket!.emit('call:ended', _pendingCallEnded!);
      _pendingCallEnded = null;
    }
  }

  // ── Disconnect ──────────────────────────────────────────────────────────
  void disconnect() {
    debugPrint('🔌 [SOCKET] Disconnecting...');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _isConnecting = false;
    _lastRequestedIds = [];
    _pendingCallStarted = null;
    _pendingCallEnded = null;
    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      _connectCompleter!.complete(false);
    }
    _connectCompleter = null;
  }
}
