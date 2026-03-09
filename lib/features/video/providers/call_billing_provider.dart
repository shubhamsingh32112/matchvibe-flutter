import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/providers/availability_provider.dart';

// ── State ──────────────────────────────────────────────────────────────────

class CallBillingState {
  final bool isActive;
  final String? callId;

  // User-facing
  final int userCoins;
  final int elapsedSeconds;
  final int remainingSeconds;
  final double pricePerSecond;

  // Creator-facing
  final double creatorEarnings;

  // Force-end
  final bool forceEnded;
  final String? forceEndReason;

  // Settlement
  final bool settled;
  final int? finalCoins;
  final int? totalDeducted;
  final int? totalEarned;
  final int? durationSeconds;
  
  // 🔥 FIX: Server time sync for accurate timer
  final int? callStartTime; // Server timestamp when call started
  final int? lastServerTimestamp; // Last server timestamp received

  const CallBillingState({
    this.isActive = false,
    this.callId,
    this.userCoins = 0,
    this.elapsedSeconds = 0,
    this.remainingSeconds = 0,
    this.pricePerSecond = 0,
    this.creatorEarnings = 0,
    this.forceEnded = false,
    this.forceEndReason,
    this.settled = false,
    this.finalCoins,
    this.totalDeducted,
    this.totalEarned,
    this.durationSeconds,
    this.callStartTime,
    this.lastServerTimestamp,
  });

  CallBillingState copyWith({
    bool? isActive,
    String? callId,
    int? userCoins,
    int? elapsedSeconds,
    int? remainingSeconds,
    double? pricePerSecond,
    double? creatorEarnings,
    bool? forceEnded,
    String? forceEndReason,
    bool? settled,
    int? finalCoins,
    int? totalDeducted,
    int? totalEarned,
    int? durationSeconds,
    int? callStartTime,
    int? lastServerTimestamp,
  }) {
    return CallBillingState(
      isActive: isActive ?? this.isActive,
      callId: callId ?? this.callId,
      userCoins: userCoins ?? this.userCoins,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      pricePerSecond: pricePerSecond ?? this.pricePerSecond,
      creatorEarnings: creatorEarnings ?? this.creatorEarnings,
      forceEnded: forceEnded ?? this.forceEnded,
      forceEndReason: forceEndReason ?? this.forceEndReason,
      settled: settled ?? this.settled,
      finalCoins: finalCoins ?? this.finalCoins,
      totalDeducted: totalDeducted ?? this.totalDeducted,
      totalEarned: totalEarned ?? this.totalEarned,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      callStartTime: callStartTime ?? this.callStartTime,
      lastServerTimestamp: lastServerTimestamp ?? this.lastServerTimestamp,
    );
  }
  
  // 🔥 FIX: Calculate accurate elapsed seconds based on server time
  int get accurateElapsedSeconds {
    if (callStartTime == null || !isActive) {
      return elapsedSeconds; // Fallback to server-provided value
    }
    
    // Calculate elapsed time based on server start time
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = ((now - callStartTime!) / 1000).floor();
    
    // Use server-provided elapsedSeconds as authoritative, but interpolate between updates
    // This ensures accuracy even if socket events are delayed
    if (lastServerTimestamp != null) {
      final timeSinceLastUpdate = ((now - lastServerTimestamp!) / 1000).floor();
      // If last update was recent (< 2 seconds), trust server value + interpolation
      if (timeSinceLastUpdate < 2) {
        return elapsedSeconds + timeSinceLastUpdate;
      }
    }
    
    // If no recent update, use calculated elapsed time
    return elapsed;
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────

class CallBillingNotifier extends StateNotifier<CallBillingState> {
  final Ref _ref;
  Timer? _clientTimer; // 🔥 FIX: Client-side timer for accurate updates

  CallBillingNotifier(this._ref) : super(const CallBillingState()) {
    _wireSocketCallbacks();
  }

  void _wireSocketCallbacks() {
    final socketService = _ref.read(socketServiceProvider);

    socketService.onBillingStarted = (data) {
      debugPrint('💰 [BILLING] Started: $data');
      
      // 🔥 FIX: Start client-side timer for accurate updates
      _startClientTimer();
      
      final serverTimestamp = (data['serverTimestamp'] as num?)?.toInt();
      final callStartTime = (data['callStartTime'] as num?)?.toInt();
      
      state = CallBillingState(
        isActive: true,
        callId: data['callId'] as String?,
        userCoins: (data['coins'] as num?)?.toInt() ?? 0,
        pricePerSecond: (data['pricePerSecond'] as num?)?.toDouble() ?? 0,
        remainingSeconds: (data['maxSeconds'] as num?)?.toInt() ?? 0,
        creatorEarnings: (data['earnings'] as num?)?.toDouble() ?? 0,
        callStartTime: callStartTime ?? serverTimestamp,
        lastServerTimestamp: serverTimestamp,
      );
    };

    socketService.onBillingUpdate = (data) {
      if (!state.isActive) return;
      
      // 🔥 FIX: Sync with server timestamps for accurate timer
      final serverTimestamp = (data['serverTimestamp'] as num?)?.toInt();
      final callStartTime = (data['callStartTime'] as num?)?.toInt();
      
      state = state.copyWith(
        userCoins: (data['coins'] as num?)?.toInt() ?? state.userCoins,
        elapsedSeconds:
            (data['elapsedSeconds'] as num?)?.toInt() ?? state.elapsedSeconds,
        remainingSeconds:
            (data['remainingSeconds'] as num?)?.toInt() ?? state.remainingSeconds,
        creatorEarnings:
            (data['earnings'] as num?)?.toDouble() ?? state.creatorEarnings,
        callStartTime: callStartTime ?? state.callStartTime,
        lastServerTimestamp: serverTimestamp,
      );
    };

    socketService.onBillingSettled = (data) {
      debugPrint('💰 [BILLING] Settled: $data');
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
      state = state.copyWith(
        forceEnded: true,
        forceEndReason: data['reason'] as String?,
      );
    };
  }

  /// 🔥 FIX: Start client-side timer for accurate updates between server events
  void _startClientTimer() {
    _clientTimer?.cancel();
    _clientTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!state.isActive) {
        timer.cancel();
        return;
      }
      
      // Update state to trigger UI refresh with accurate elapsed time
      // The accurateElapsedSeconds getter will calculate the correct time
      state = state.copyWith();
    });
  }

  /// Reset billing state (call ended, user dismissed dialogs).
  void reset() {
    _clientTimer?.cancel();
    _clientTimer = null;
    state = const CallBillingState();
  }

  @override
  void dispose() {
    _clientTimer?.cancel();
    // Clear callbacks to avoid memory leaks
    try {
      final socketService = _ref.read(socketServiceProvider);
      socketService.onBillingStarted = null;
      socketService.onBillingUpdate = null;
      socketService.onBillingSettled = null;
      socketService.onCallForceEnd = null;
    } catch (_) {}
    super.dispose();
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

final callBillingProvider =
    StateNotifierProvider<CallBillingNotifier, CallBillingState>((ref) {
  return CallBillingNotifier(ref);
});
