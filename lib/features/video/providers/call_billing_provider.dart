import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/providers/availability_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../controllers/call_connection_controller.dart';

// ── State ──────────────────────────────────────────────────────────────────
//
// Monetary display and billed elapsed time come only from server `billing:*`
// events. No client-side deduction, earnings math, or local billing timer ticks.

class CallBillingState {
  final bool isActive;
  final String? callId;

  /// User wallet balance during call — from server only (`billing:*` events).
  final int userCoins;

  /// Creator earnings during call — from server only.
  final double creatorEarnings;

  /// Billed seconds (authoritative) — from server only.
  final int elapsedSeconds;

  /// User: affordable seconds at current rate; null for creator-focused payloads.
  final int? remainingSeconds;

  /// Max call length (seconds) when server sends `durationLimit`.
  final int? durationLimit;

  /// Rate from `billing:started` (user: coin/sec; creator: display rate from server).
  final num? pricePerSecond;

  /// Last `serverTimestamp` from billing event (ms since epoch).
  final int? lastServerTimestampMs;

  /// Session `callStartTime` from server (ms since epoch).
  final int? callStartTimeMs;

  final bool forceEnded;
  final String? forceEndReason;

  final bool settled;
  final int? finalCoins;
  final int? totalDeducted;
  final int? totalEarned;
  final int? durationSeconds;

  /// Display-only: estimated coins after last server snapshot (smooth if socket lags).
  int get estimatedUserCoins {
    final ts = lastServerTimestampMs;
    final pps = pricePerSecond;
    if (ts == null || pps == null) return userCoins;
    final extraMs = DateTime.now().millisecondsSinceEpoch - ts;
    if (extraMs <= 0) return userCoins;
    final burn = (extraMs / 1000.0) * pps.toDouble();
    return math.max(0, userCoins - burn.floor());
  }

  /// Display-only: estimated creator earnings after last server snapshot.
  double get estimatedCreatorEarningsDisplay {
    final ts = lastServerTimestampMs;
    final rate = pricePerSecond;
    if (ts == null || rate == null) return creatorEarnings;
    final extraMs = DateTime.now().millisecondsSinceEpoch - ts;
    if (extraMs <= 0) return creatorEarnings;
    final add = (extraMs / 1000.0) * rate.toDouble();
    return creatorEarnings + add;
  }

  const CallBillingState({
    this.isActive = false,
    this.callId,
    this.userCoins = 0,
    this.creatorEarnings = 0,
    this.elapsedSeconds = 0,
    this.remainingSeconds,
    this.durationLimit,
    this.pricePerSecond,
    this.lastServerTimestampMs,
    this.callStartTimeMs,
    this.forceEnded = false,
    this.forceEndReason,
    this.settled = false,
    this.finalCoins,
    this.totalDeducted,
    this.totalEarned,
    this.durationSeconds,
  });

  CallBillingState copyWith({
    bool? isActive,
    String? callId,
    int? userCoins,
    double? creatorEarnings,
    int? elapsedSeconds,
    int? remainingSeconds,
    int? durationLimit,
    num? pricePerSecond,
    int? lastServerTimestampMs,
    int? callStartTimeMs,
    bool? forceEnded,
    String? forceEndReason,
    bool? settled,
    int? finalCoins,
    int? totalDeducted,
    int? totalEarned,
    int? durationSeconds,
  }) {
    return CallBillingState(
      isActive: isActive ?? this.isActive,
      callId: callId ?? this.callId,
      userCoins: userCoins ?? this.userCoins,
      creatorEarnings: creatorEarnings ?? this.creatorEarnings,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      durationLimit: durationLimit ?? this.durationLimit,
      pricePerSecond: pricePerSecond ?? this.pricePerSecond,
      lastServerTimestampMs:
          lastServerTimestampMs ?? this.lastServerTimestampMs,
      callStartTimeMs: callStartTimeMs ?? this.callStartTimeMs,
      forceEnded: forceEnded ?? this.forceEnded,
      forceEndReason: forceEndReason ?? this.forceEndReason,
      settled: settled ?? this.settled,
      finalCoins: finalCoins ?? this.finalCoins,
      totalDeducted: totalDeducted ?? this.totalDeducted,
      totalEarned: totalEarned ?? this.totalEarned,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}

int? _readIntMs(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

// ── Notifier ───────────────────────────────────────────────────────────────

class CallBillingNotifier extends StateNotifier<CallBillingState> {
  final Ref _ref;

  late final void Function() _onSocketReconnected;
  Timer? _billingRecoveryRetryTimer;
  int _billingRecoveryAttempts = 0;
  static const int _maxBillingRecoveryAttempts = 10;
  Timer? _connectedWithoutBillingTimer;
  DateTime? _connectedStuckSince;
  DateTime? _lastOrphanRecoveryEmit;
  bool _stuckEndRequested = false;

  CallBillingNotifier(this._ref) : super(const CallBillingState()) {
    _onSocketReconnected = () {
      _startBillingRecoveryRetry();
    };
    _wireSocketCallbacks();
    _connectedWithoutBillingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _onConnectedWithoutBillingWatchTick();
    });
  }

  void _startBillingRecoveryRetry() {
    _billingRecoveryRetryTimer?.cancel();
    _billingRecoveryAttempts = 0;
    _requestBillingRecoveryWithBackoff();
  }

  void _requestBillingRecoveryWithBackoff() {
    if (state.isActive && state.callStartTimeMs != null) return;
    if (_billingRecoveryAttempts >= _maxBillingRecoveryAttempts) {
      debugPrint(
        '💰 [BILLING] billing_recovery_failed attempts=$_billingRecoveryAttempts callId=${state.callId}',
      );
      return;
    }
    _billingRecoveryAttempts += 1;
    final socketService = _ref.read(socketServiceProvider);
    debugPrint(
      '💰 [BILLING] billing_recovery_requested attempt=$_billingRecoveryAttempts callId=${state.callId}',
    );
    socketService.requestBillingStateRecovery();

    final nextDelaySeconds = math.min(5, 1 << (_billingRecoveryAttempts - 1));
    _billingRecoveryRetryTimer = Timer(
      Duration(seconds: nextDelaySeconds),
      _requestBillingRecoveryWithBackoff,
    );
  }

  void _stopBillingRecoveryRetry() {
    _billingRecoveryRetryTimer?.cancel();
    _billingRecoveryRetryTimer = null;
    _billingRecoveryAttempts = 0;
  }

  void _onConnectedWithoutBillingWatchTick() {
    final phase = _ref.read(callConnectionControllerProvider).phase;
    if (phase != CallConnectionPhase.connected) {
      _connectedStuckSince = null;
      _stuckEndRequested = false;
      _lastOrphanRecoveryEmit = null;
      return;
    }
    if (state.isActive || state.callStartTimeMs != null) {
      _connectedStuckSince = null;
      _stuckEndRequested = false;
      _lastOrphanRecoveryEmit = null;
      return;
    }
    _connectedStuckSince ??= DateTime.now();
    final stuckFor = DateTime.now().difference(_connectedStuckSince!);

    if (stuckFor > const Duration(milliseconds: 1500)) {
      final now = DateTime.now();
      if (_lastOrphanRecoveryEmit == null ||
          now.difference(_lastOrphanRecoveryEmit!) > const Duration(seconds: 2)) {
        _lastOrphanRecoveryEmit = now;
        final socketService = _ref.read(socketServiceProvider);
        socketService.requestBillingStateRecovery();

        // If the call is already connected but the billing socket isn't, try to
        // reconnect immediately so `billing:started` / recover-state can land
        // within the 8s safety window.
        if (!socketService.isConnected) {
          final firebaseUser = _ref.read(authProvider).firebaseUser;
          if (firebaseUser != null) {
            unawaited(() async {
              try {
                final token = await firebaseUser.getIdToken();
                if (token != null) {
                  await socketService.ensureConnected(token);
                }
              } catch (_) {}
            }());
          }
        }
      }
    }
    if (stuckFor > const Duration(seconds: 8) && !_stuckEndRequested) {
      _stuckEndRequested = true;
      debugPrint(
        '💰 [BILLING] billing_stuck_ending_call no_active_billing after ${stuckFor.inSeconds}s',
      );
      unawaited(_ref.read(callConnectionControllerProvider.notifier).endCall());
    }
  }

  void _wireSocketCallbacks() {
    final socketService = _ref.read(socketServiceProvider);
    socketService.onReconnected = _onSocketReconnected;

    socketService.onBillingStarted = (data) {
      debugPrint('💰 [BILLING] Started: $data');
      _stopBillingRecoveryRetry();
      final callId = data['callId'] as String?;
      final coins = (data['coins'] as num?)?.toInt();
      final earnings = (data['earnings'] as num?)?.toDouble();
      final maxSeconds = (data['maxSeconds'] as num?)?.toInt();
      final elapsed = (data['elapsedSeconds'] as num?)?.toInt() ?? 0;
      final remainingFromPayload =
          (data['remainingSeconds'] as num?)?.toInt();
      final pricePerSecond = data['pricePerSecond'] as num?;
      final serverTs = _readIntMs(data['serverTimestamp']);
      final startMs = _readIntMs(data['callStartTime']);
      final durationLimit = (data['durationLimit'] as num?)?.toInt();

      state = CallBillingState(
        isActive: true,
        callId: callId,
        userCoins: coins ?? 0,
        creatorEarnings: earnings ?? 0,
        elapsedSeconds: elapsed,
        remainingSeconds: remainingFromPayload ?? maxSeconds,
        durationLimit: durationLimit,
        pricePerSecond: pricePerSecond,
        lastServerTimestampMs: serverTs,
        callStartTimeMs: startMs,
      );
    };

    socketService.onBillingUpdate = (data) {
      if (!state.isActive) return;

      final eventCallId = data['callId'] as String?;
      if (eventCallId == null || eventCallId != state.callId) {
        debugPrint(
            '💰 [BILLING] Ignoring billing:update for different call: event=$eventCallId current=${state.callId}');
        return;
      }

      final coins = (data['coins'] as num?)?.toInt();
      final earnings = (data['earnings'] as num?)?.toDouble();
      final elapsed = (data['elapsedSeconds'] as num?)?.toInt();
      final remaining = (data['remainingSeconds'] as num?)?.toInt();
      final durationLimit = (data['durationLimit'] as num?)?.toInt();
      final serverTs = _readIntMs(data['serverTimestamp']);
      final startMs = _readIntMs(data['callStartTime']);

      state = state.copyWith(
        userCoins: coins ?? state.userCoins,
        creatorEarnings: earnings ?? state.creatorEarnings,
        elapsedSeconds: elapsed ?? state.elapsedSeconds,
        remainingSeconds: remaining ?? state.remainingSeconds,
        durationLimit: durationLimit ?? state.durationLimit,
        lastServerTimestampMs: serverTs ?? state.lastServerTimestampMs,
        callStartTimeMs: startMs ?? state.callStartTimeMs,
      );
    };

    socketService.onBillingSettled = (data) {
      debugPrint('💰 [BILLING] Settled: $data');
      final eventCallId = data['callId'] as String?;
      if (eventCallId == null || eventCallId != state.callId) {
        debugPrint(
            '💰 [BILLING] Ignoring billing:settled for different call: event=$eventCallId current=${state.callId}');
        return;
      }
      state = state.copyWith(
        isActive: false,
        settled: true,
        finalCoins: (data['finalCoins'] as num?)?.toInt(),
        totalDeducted: (data['totalDeducted'] as num?)?.toInt(),
        totalEarned: (data['totalEarned'] as num?)?.toInt(),
        durationSeconds: (data['durationSeconds'] as num?)?.toInt(),
      );
    };

    socketService.onCallForceEnd = (data) {
      debugPrint('🚨 [BILLING] Force end: $data');
      final eventCallId = data['callId'] as String?;
      if (eventCallId == null || eventCallId != state.callId) {
        debugPrint(
            '🚨 [BILLING] Ignoring call:force-end for different call: event=$eventCallId current=${state.callId}');
        return;
      }
      state = state.copyWith(
        forceEnded: true,
        forceEndReason: data['reason'] as String?,
      );
    };

    socketService.onBillingRecoverState = _onBillingRecoverState;
  }

  void _onBillingRecoverState(Map<String, dynamic> data) {
    var expected = state.callId;
    if (expected == null) {
      final list = data['activeCalls'];
      if (list is List && list.length == 1 && list.first is Map) {
        expected =
            (list.first as Map)['callId']?.toString();
      }
    }
    if (expected == null || expected.isEmpty) {
      debugPrint('💰 [BILLING] Recover skipped — could not resolve callId');
      return;
    }
    mergeRecoverPayload(data, expectedCallId: expected);
  }

  /// Apply `billing:recover-state:response` for [expectedCallId] (e.g. from controller when state.callId is not yet set).
  void mergeRecoverPayload(
    Map<String, dynamic> data, {
    required String expectedCallId,
  }) {
    final ok = data['success'] == true;
    if (!ok) return;
    final list = data['activeCalls'];
    if (list is! List || list.isEmpty) return;

    Map<String, dynamic>? m;
    for (final item in list) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(
        item.map(
          (k, v) => MapEntry(k.toString(), v),
        ),
      );
      if (map['callId'] == expectedCallId) {
        m = map;
        break;
      }
    }
    if (m == null) {
      debugPrint(
          '💰 [BILLING] Recover: no entry for callId=$expectedCallId');
      return;
    }

    final coins = (m['coins'] as num?)?.toInt() ?? state.userCoins;
    final earnings =
        (m['earnings'] as num?)?.toDouble() ?? state.creatorEarnings;
    final elapsed =
        (m['elapsedSeconds'] as num?)?.toInt() ?? state.elapsedSeconds;
    final remaining = (m['remainingSeconds'] as num?)?.toInt();
    final pricePerSecond = m['pricePerSecond'] as num? ?? state.pricePerSecond;
    final serverTs = _readIntMs(m['serverTimestamp']);
    final startMs = _readIntMs(m['callStartTime']);

    state = state.copyWith(
      isActive: true,
      callId: expectedCallId,
      userCoins: coins,
      creatorEarnings: earnings,
      elapsedSeconds: elapsed,
      remainingSeconds: remaining ?? state.remainingSeconds,
      pricePerSecond: pricePerSecond,
      lastServerTimestampMs: serverTs ?? state.lastServerTimestampMs,
      callStartTimeMs: startMs ?? state.callStartTimeMs,
    );
    _stopBillingRecoveryRetry();
    debugPrint('💰 [BILLING] billing_recovery_succeeded callId=$expectedCallId');
    debugPrint('💰 [BILLING] Recovered state for call $expectedCallId');
  }

  void reset() {
    _stopBillingRecoveryRetry();
    _connectedStuckSince = null;
    _stuckEndRequested = false;
    _lastOrphanRecoveryEmit = null;
    state = const CallBillingState();
  }

  @override
  void dispose() {
    try {
      _stopBillingRecoveryRetry();
      _connectedWithoutBillingTimer?.cancel();
      _connectedWithoutBillingTimer = null;
      final socketService = _ref.read(socketServiceProvider);
      if (identical(socketService.onReconnected, _onSocketReconnected)) {
        socketService.onReconnected = null;
      }
      socketService.onBillingStarted = null;
      socketService.onBillingUpdate = null;
      socketService.onBillingSettled = null;
      socketService.onCallForceEnd = null;
      socketService.onBillingRecoverState = null;
    } catch (_) {}
    super.dispose();
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

final callBillingProvider =
    StateNotifierProvider<CallBillingNotifier, CallBillingState>((ref) {
  return CallBillingNotifier(ref);
});
