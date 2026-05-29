//D:\zztherapy\frontend\lib\core\services\socket_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/app_constants.dart';
import '../api/api_client.dart';
import 'sentry_service.dart';
import '../../features/video/services/billing_convergence_metrics.dart';

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
  static const int _availabilityChunkSize = 100;
  io.Socket? _socket;
  bool _isConnected = false;
  bool _isConnecting = false;
  List<String> _lastRequestedIds = [];
  final Set<String> _trackedCreatorIds = <String>{};

  /// Fan UIDs last requested via [user:availability:get] (creators) — re-sent on reconnect.
  List<String> _lastRequestedUserIds = [];
  final Set<String> _trackedUserIds = <String>{};
  Completer<bool>? _connectCompleter;
  String? _currentAuthToken;
  bool _isRefreshingSocketToken = false;
  DateTime? _lastSocketTokenRefreshAt;
  // ── Pending billing events (queued when socket is disconnected) ─────────
  Map<String, dynamic>? _pendingCallStarted;
  Map<String, dynamic>? _pendingCallEnded;
  bool _pendingBillingRecoverState = false;
  String? _pendingBillingRecoverRequestId;
  int _billingRecoverRequestSeq = 0;
  final Set<String> _billingStartedSeenCallIds = <String>{};

  // ── Availability callbacks ──────────────────────────────────────────────
  void Function(Map<String, String>)? onAvailabilityBatch;
  void Function(Map<String, Map<String, dynamic>> data)? onAvailabilityBatchV2;
  void Function(String creatorId, String status)? onCreatorStatus;
  void Function(
    String creatorId,
    String status, {
    int? version,
    int? updatedAt,
  })?
  onCreatorStatusV2;

  /// Fan online/offline — server emits to `creators` room only.
  void Function(String firebaseUid, String status)? onUserStatus;

  /// Response to [user:availability:get] — Redis-backed batch for creators.
  void Function(Map<String, String> batch)? onUserAvailabilityBatch;

  // ── Billing callbacks ──────────────────────────────────────────────────
  void Function(Map<String, dynamic>)? onBillingStarted;
  void Function(Map<String, dynamic>)? onBillingUpdate;
  void Function(Map<String, dynamic>)? onBillingSettled;
  void Function(Map<String, dynamic>)? onCallForceEnd;
  void Function(Map<String, dynamic>)? onBillingError;

  /// Response to [requestBillingStateRecovery] — same shape as server recover payload.
  void Function(Map<String, dynamic>)? onBillingRecoverState;

  /// Fired after a successful Socket.IO connect (initial and reconnect).
  void Function()? onConnected;

  /// Fired when the socket disconnects.
  void Function()? onDisconnected;

  /// Fired after a successful Socket.IO reconnect (not the initial connect).
  void Function()? onReconnected;

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

  /// Fired when admin publishes a global app update popup payload.
  void Function(Map<String, dynamic>)? onAppUpdatePublished;

  /// Fired when admin updates a support ticket (status / notes).
  void Function(Map<String, dynamic>)? onSupportTicketUpdated;
  Future<String?> Function()? refreshSocketAuthToken;

  bool get isConnected => _isConnected;

  // ── Connect ─────────────────────────────────────────────────────────────
  /// Connect to the Socket.IO server.
  ///
  /// 🔥 FIX: If the socket exists but is NOT connected (stale), it is
  /// disposed and re-created.  The old code had `if (_socket != null) return`
  /// which silently skipped reconnection attempts after the first failure.
  void connect(String firebaseToken) {
    _currentAuthToken = firebaseToken;
    // Already connected — refresh listeners (e.g. creator status provider created after connect).
    if (_socket != null && _isConnected) {
      debugPrint('🔌 [SOCKET] Already connected, skipping');
      onConnected?.call();
      return;
    }

    // Connection in progress — avoid duplicate reconnect storms.
    if (_isConnecting) {
      debugPrint('🔌 [SOCKET] Connection already in progress, skipping');
      return;
    }

    // Socket exists but is NOT connected → dispose stale socket first
    if (_socket != null) {
      debugPrint(
        '🔌 [SOCKET] Stale socket detected (not connected). Disposing and reconnecting...',
      );
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
          .setAuth({'token': _currentAuthToken})
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('✅ [SOCKET] Connected to ${AppConstants.socketUrl}');
      SentryService.addBreadcrumb(
        category: 'socket',
        message: 'socket.connect',
      );
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
        _emitCreatorAvailabilityHydration();
      }
      if (_lastRequestedUserIds.isNotEmpty) {
        debugPrint(
          '📡 [SOCKET] Auto-requesting user availability for ${_lastRequestedUserIds.length} user(s)',
        );
        _emitUserAvailabilityHydration();
      }

      // Flush any pending billing events that were queued while disconnected
      _flushPendingBillingEvents();
      onConnected?.call();
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

    _socket!.on('availability:batch:v2', (data) {
      debugPrint('📡 [SOCKET] Received availability:batch:v2');
      if (data is Map) {
        final mapped = <String, Map<String, dynamic>>{};
        data.forEach((key, value) {
          if (key == null || value is! Map) return;
          mapped[key.toString()] = Map<String, dynamic>.from(
            value.map((k, v) => MapEntry(k.toString(), v)),
          );
        });
        onAvailabilityBatchV2?.call(mapped);
      }
    });

    _socket!.on('creator:status', (data) {
      debugPrint('📡 [SOCKET] Received creator:status event: $data');
      if (data is Map) {
        final creatorId = data['creatorId']?.toString();
        final status = data['status']?.toString();
        if (creatorId != null && status != null) {
          debugPrint(
            '📡 [SOCKET] Calling onCreatorStatus callback: $creatorId → $status',
          );
          final version = (data['version'] as num?)?.toInt();
          final updatedAt = (data['updatedAt'] as num?)?.toInt();
          if (onCreatorStatus != null && version == null) {
            onCreatorStatus!(creatorId, status);
            debugPrint('✅ [SOCKET] onCreatorStatus callback executed');
          } else {
            debugPrint(
              '⚠️  [SOCKET] onCreatorStatus callback skipped (prefer v2/versioned path).',
            );
          }
          onCreatorStatusV2?.call(
            creatorId,
            status,
            version: version,
            updatedAt: updatedAt,
          );
        } else {
          debugPrint(
            '⚠️  [SOCKET] Invalid creator:status data: creatorId=$creatorId, status=$status',
          );
        }
      } else {
        debugPrint(
          '⚠️  [SOCKET] creator:status data is not a Map: ${data.runtimeType}',
        );
      }
    });

    _socket!.on('user:status', (data) {
      if (data is Map) {
        final uid = data['firebaseUid']?.toString();
        final status = data['status']?.toString();
        if (uid != null && status != null) {
          onUserStatus?.call(uid, status);
        }
      }
    });

    _socket!.on('user:availability:batch', (data) {
      if (data is Map) {
        final map = Map<String, String>.from(
          data.map((k, v) => MapEntry(k.toString(), v.toString())),
        );
        onUserAvailabilityBatch?.call(map);
      }
    });

    // ── Billing events ──────────────────────────────────────────────────
    _socket!.on('billing:started', (data) {
      debugPrint('💰 [SOCKET] billing:started: $data');
      _socketEventBreadcrumb('billing:started', data);
      if (data is Map) {
        final callId = data['callId']?.toString();
        if (callId != null && callId.isNotEmpty) {
          _billingStartedSeenCallIds.add(callId);
        }
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
      _socketEventBreadcrumb('billing:settled', data);
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
      _socketEventBreadcrumb('billing:error', data);
      if (data is Map) {
        onBillingError?.call(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('billing:recover-state:response', (data) {
      debugPrint('💰 [SOCKET] billing:recover-state:response: $data');
      if (data is Map) {
        final mapped = Map<String, dynamic>.from(data);
        SentryService.addThrottledBreadcrumb(
          category: 'billing.recover',
          message: 'billing_recovery_response',
          data: {
            'status': mapped['status']?.toString(),
            'reason': mapped['reason']?.toString(),
            'recovery_outcome': mapped['recoveryOutcome']?.toString(),
            'client_recovery_request_id':
                mapped['clientRecoveryRequestId']?.toString(),
            'active_calls_count': (mapped['activeCalls'] is List)
                ? (mapped['activeCalls'] as List).length
                : -1,
          },
        );
        onBillingRecoverState?.call(Map<String, dynamic>.from(data));
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

    _socket!.on('app_update:published', (data) {
      debugPrint('🆕 [SOCKET] app_update:published: $data');
      if (data is Map) {
        onAppUpdatePublished?.call(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('support:ticket_updated', (data) {
      debugPrint('🎫 [SOCKET] support:ticket_updated: $data');
      if (data is Map) {
        onSupportTicketUpdated?.call(Map<String, dynamic>.from(data));
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('🔌 [SOCKET] Disconnected');
      BillingConvergenceMetrics.instance.onSocketDisconnect();
      SentryService.addBreadcrumb(
        category: 'socket',
        message: 'socket.disconnect',
      );
      _isConnected = false;
      _isConnecting = false;
      onDisconnected?.call();
    });

    _socket!.onReconnect((_) {
      debugPrint('🔌 [SOCKET] Reconnected');
      BillingConvergenceMetrics.instance.onSocketReconnect();
      SentryService.addBreadcrumb(
        category: 'socket',
        message: 'socket.reconnect',
        data: {
          'socket.reconnect': 'true',
          ...BillingConvergenceMetrics.instance
              .snapshot()
              .map((k, v) => MapEntry(k, v.toString())),
        },
      );
      _isConnected = true;

      // Re-hydrate availability after reconnect
      if (_lastRequestedIds.isNotEmpty) {
        _emitCreatorAvailabilityHydration();
      }
      if (_lastRequestedUserIds.isNotEmpty) {
        _emitUserAvailabilityHydration();
      }

      // Flush any pending billing events that were queued while disconnected
      _flushPendingBillingEvents();

      onConnected?.call();
      onReconnected?.call();
    });

    _socket!.onConnectError((error) {
      debugPrint('❌ [SOCKET] Connection error: $error');
      _isConnecting = false;
      final errorText = error.toString().toLowerCase();
      final isAuthFailure =
          errorText.contains('authentication error') ||
          errorText.contains('invalid token') ||
          errorText.contains('id-token') ||
          errorText.contains('jwt');
      if (isAuthFailure) {
        unawaited(_refreshSocketTokenAndReconnect());
      }
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

    debugPrint(
      '🔄 [SOCKET] ensureConnected — socket is NOT connected, reconnecting...',
    );
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
          '⚠️ [SOCKET] ensureConnected — timed out/failed, continuing without socket',
        );
      }
      return connected;
    } finally {
      _connectCompleter = null;
    }
  }

  /// Belt-and-suspenders: server also sets online on connect; this helps if
  /// the gateway path is delayed.
  void emitCreatorOnline() {
    if (!_isConnected || _socket == null) return;
    debugPrint('📡 [SOCKET] Emitting creator:online');
    _socket!.emit('creator:online');
  }

  void emitCreatorOffline() {
    if (!_isConnected || _socket == null) return;
    debugPrint('📡 [SOCKET] Emitting creator:offline');
    _socket!.emit('creator:offline');
  }

  void emitUserOffline() {
    if (!_isConnected || _socket == null) return;
    debugPrint('📡 [SOCKET] Emitting user:offline');
    _socket!.emit('user:offline');
  }

  // ── Request Availability ────────────────────────────────────────────────
  /// Emit [availability:get] with the given creator Firebase UIDs.
  /// If the socket is not yet connected the IDs are queued and will be
  /// sent automatically when the connection is established.
  void requestAvailability(List<String> creatorIds) {
    final sanitized = creatorIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (sanitized.isEmpty) return;

    _trackedCreatorIds.addAll(sanitized);
    _lastRequestedIds = _trackedCreatorIds.toList(growable: false);

    if (!_isConnected || _socket == null) {
      debugPrint(
        '⏳ [SOCKET] Not connected yet — availability request queued (${sanitized.length} IDs)',
      );
      return;
    }

    debugPrint(
      '📡 [SOCKET] Emitting availability:get for ${sanitized.length} creator(s)',
    );
    _socket!.emit('availability:get', {'creatorIds': sanitized});
  }

  /// Emit [user:availability:get] with fan Firebase UIDs (creators / admin in creator tools).
  void requestUserAvailability(List<String> userFirebaseUids) {
    final sanitized = userFirebaseUids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (sanitized.isEmpty) return;

    _trackedUserIds.addAll(sanitized);
    _lastRequestedUserIds = _trackedUserIds.toList(growable: false);

    if (!_isConnected || _socket == null) {
      debugPrint(
        '⏳ [SOCKET] Not connected — user availability request queued (${sanitized.length} IDs)',
      );
      return;
    }

    debugPrint(
      '📡 [SOCKET] Emitting user:availability:get for ${sanitized.length} user(s)',
    );
    _socket!.emit('user:availability:get', sanitized);
  }

  // ── Billing Emitters ────────────────────────────────────────────────────

  /// Notify the backend that a call has started (triggers billing loop).
  ///
  /// 🔥 FIX: If the socket is not connected, we now call the REST API
  /// directly as a fallback so billing is never silently dropped.
  ///
  /// [userFirebaseUid] - Optional. For creator-initiated calls, specifies the user who pays.
  ///                     For user-initiated calls, this is null and the socket owner pays.
  /// Returns true when billing was started via HTTP and a snapshot was applied.
  Future<bool> emitCallStarted({
    required String callId,
    required String creatorFirebaseUid,
    required String creatorMongoId,
    String? userFirebaseUid,
  }) async {
    final data = <String, dynamic>{
      'callId': callId,
      'creatorFirebaseUid': creatorFirebaseUid,
      'creatorMongoId': creatorMongoId,
      ...?userFirebaseUid == null
          ? null
          : <String, dynamic>{'userFirebaseUid': userFirebaseUid},
    };

    if (_socket != null && _isConnected) {
      debugPrint('💰 [SOCKET] Emitting call:started for $callId');
      _socket!.emit('call:started', data);
      _pendingCallStarted = null;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (_billingStartedSeenCallIds.contains(callId)) {
        return false;
      }
      debugPrint(
        '⚠️ [SOCKET] call:started emitted but billing:started not seen quickly. Triggering HTTP fallback for $callId',
      );
      return _billingViaHttp('call-started', data);
    }

    // Socket not connected → use REST API fallback
    debugPrint(
      '⚠️ [SOCKET] Cannot emit call:started — not connected. Using REST API fallback for $callId',
    );
    _pendingCallStarted = data;
    return _billingViaHttp('call-started', data);
  }

  /// Notify the backend that a call has ended (triggers settlement).
  ///
  /// 🔥 FIX: If the socket is not connected, we now call the REST API
  /// directly as a fallback so settlement is never silently dropped.
  /// Ask the server for Redis-backed billing snapshot (mid-call reconnect).
  void requestBillingStateRecovery({String? callId, String? phase}) {
    final requestId = 'rec_${DateTime.now().millisecondsSinceEpoch}_${++_billingRecoverRequestSeq}';
    SentryService.addThrottledBreadcrumb(
      category: 'billing.recover',
      message: 'billing_recovery_requested',
      data: {
        'client_recovery_request_id': requestId,
        if (callId != null) 'call_id': callId,
        if (phase != null) 'phase': phase,
        'socket_connected': _isConnected,
      },
    );
    if (_socket != null && _isConnected) {
      debugPrint('💰 [SOCKET] Emitting billing:recover-state');
      _socket!.emit('billing:recover-state', {'clientRecoveryRequestId': requestId});
      _pendingBillingRecoverState = false;
      _pendingBillingRecoverRequestId = null;
      return;
    }
    // Socket not connected → queue for next reconnect.
    _pendingBillingRecoverState = true;
    _pendingBillingRecoverRequestId = requestId;
    debugPrint('⏳ [SOCKET] Not connected — billing:recover-state queued');
  }

  void emitCallEnded({required String callId}) {
    final data = {'callId': callId};

    if (_socket != null && _isConnected) {
      debugPrint('💰 [SOCKET] Emitting call:ended for $callId');
      _socket!.emit('call:ended', data);
      _pendingCallEnded = null;
      _billingStartedSeenCallIds.remove(callId);
      return;
    }

    // Socket not connected → use REST API fallback
    debugPrint(
      '⚠️ [SOCKET] Cannot emit call:ended — not connected. Using REST API fallback for $callId',
    );
    _pendingCallEnded = data;
    _billingViaHttp('call-ended', data);
  }

  /// Report prolonged "Syncing billing..." state to backend logs.
  void emitBillingSyncWarning({
    required String callId,
    required int stuckSeconds,
    required String phase,
  }) {
    final data = <String, dynamic>{
      'callId': callId,
      'stuckSeconds': stuckSeconds,
      'phase': phase,
      'reportedAt': DateTime.now().toIso8601String(),
    };
    if (_socket != null && _isConnected) {
      _socket!.emit('billing:sync-warning', data);
      return;
    }
    debugPrint(
      '⚠️ [SOCKET] billing:sync-warning dropped (socket disconnected) callId=$callId',
    );
  }

  /// REST API fallback for billing events when the socket is down.
  /// For `call-started`, returns true when the response includes a billing snapshot.
  Future<bool> _billingViaHttp(String event, Map<String, dynamic> data) async {
    try {
      debugPrint('🌐 [BILLING HTTP] POST /billing/$event with data: $data');
      final response = await ApiClient().post('/billing/$event', data: data);
      debugPrint('✅ [BILLING HTTP] $event response: ${response.statusCode}');
      // Clear the pending event on success
      if (event == 'call-started') {
        _pendingCallStarted = null;
        final body = response.data;
        if (body is Map) {
          final billing = body['billing'];
          if (billing is Map) {
            onBillingStarted?.call(Map<String, dynamic>.from(billing));
            return true;
          }
        }
        return false;
      } else if (event == 'call-ended') {
        _pendingCallEnded = null;
        final callId = data['callId']?.toString();
        if (callId != null && callId.isNotEmpty) {
          _billingStartedSeenCallIds.remove(callId);
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ [BILLING HTTP] $event failed: $e');
      // Keep the pending event so it can be flushed on socket reconnect
      return false;
    }
  }

  /// Flush any pending billing events that were queued while disconnected.
  void _flushPendingBillingEvents() {
    if (_socket == null || !_isConnected) return;

    if (_pendingCallStarted != null) {
      debugPrint(
        '💰 [SOCKET] Flushing queued call:started for ${_pendingCallStarted!['callId']}',
      );
      _socket!.emit('call:started', _pendingCallStarted!);
      _pendingCallStarted = null;
    }

    if (_pendingCallEnded != null) {
      debugPrint(
        '💰 [SOCKET] Flushing queued call:ended for ${_pendingCallEnded!['callId']}',
      );
      _socket!.emit('call:ended', _pendingCallEnded!);
      _pendingCallEnded = null;
    }

    if (_pendingBillingRecoverState) {
      debugPrint('💰 [SOCKET] Flushing queued billing:recover-state');
      _socket!.emit('billing:recover-state', {
        if (_pendingBillingRecoverRequestId != null)
          'clientRecoveryRequestId': _pendingBillingRecoverRequestId,
      });
      _pendingBillingRecoverState = false;
      _pendingBillingRecoverRequestId = null;
    }
  }

  void _socketEventBreadcrumb(String event, dynamic data) {
    String? callId;
    if (data is Map) {
      callId = data['callId']?.toString() ?? data['call_id']?.toString();
    }
    SentryService.addBreadcrumb(
      category: 'socket',
      message: event,
      data: {'event': event, if (callId != null) 'callId': callId},
    );
  }

  // ── Disconnect ──────────────────────────────────────────────────────────
  void disconnect({bool emitPresenceOffline = false, bool isCreator = false}) {
    debugPrint('🔌 [SOCKET] Disconnecting...');
    if (emitPresenceOffline && _isConnected && _socket != null) {
      if (isCreator) {
        emitCreatorOffline();
      } else {
        emitUserOffline();
      }
    }
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _isConnecting = false;
    _currentAuthToken = null;
    _lastRequestedIds = [];
    _lastRequestedUserIds = [];
    _trackedCreatorIds.clear();
    _trackedUserIds.clear();
    _pendingCallStarted = null;
    _pendingCallEnded = null;
    _pendingBillingRecoverState = false;
    _pendingBillingRecoverRequestId = null;
    _billingStartedSeenCallIds.clear();
    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      _connectCompleter!.complete(false);
    }
    _connectCompleter = null;
  }

  void _emitCreatorAvailabilityHydration() {
    if (!_isConnected || _socket == null || _lastRequestedIds.isEmpty) return;
    for (var i = 0; i < _lastRequestedIds.length; i += _availabilityChunkSize) {
      final end = (i + _availabilityChunkSize > _lastRequestedIds.length)
          ? _lastRequestedIds.length
          : i + _availabilityChunkSize;
      _socket!.emit('availability:get', {'creatorIds': _lastRequestedIds.sublist(i, end)});
    }
  }

  void _emitUserAvailabilityHydration() {
    if (!_isConnected || _socket == null || _lastRequestedUserIds.isEmpty) return;
    for (var i = 0; i < _lastRequestedUserIds.length; i += _availabilityChunkSize) {
      final end = (i + _availabilityChunkSize > _lastRequestedUserIds.length)
          ? _lastRequestedUserIds.length
          : i + _availabilityChunkSize;
      _socket!.emit('user:availability:get', _lastRequestedUserIds.sublist(i, end));
    }
  }

  Future<void> _refreshSocketTokenAndReconnect() async {
    if (_isRefreshingSocketToken) return;
    final refresher = refreshSocketAuthToken;
    if (refresher == null) return;
    final now = DateTime.now();
    if (_lastSocketTokenRefreshAt != null &&
        now.difference(_lastSocketTokenRefreshAt!) < const Duration(seconds: 5)) {
      return;
    }
    _isRefreshingSocketToken = true;
    try {
      _lastSocketTokenRefreshAt = now;
      final refreshedToken = await refresher();
      if (refreshedToken == null || refreshedToken.isEmpty) {
        debugPrint('⚠️ [SOCKET] Token refresh callback returned empty token');
        return;
      }
      _currentAuthToken = refreshedToken;
      if (_socket != null) {
        _socket!.auth = {'token': refreshedToken};
        _socket!.disconnect();
        _socket!.connect();
      } else {
        connect(refreshedToken);
      }
      debugPrint('🔑 [SOCKET] Refreshed auth token and retried connect');
    } catch (e) {
      debugPrint('⚠️ [SOCKET] Token refresh for socket failed: $e');
    } finally {
      _isRefreshingSocketToken = false;
    }
  }
}
