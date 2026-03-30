import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/providers/availability_provider.dart';

// ── State ──────────────────────────────────────────────────────────────────

class CallBillingState {
  final bool isActive;
  final String? callId;

  // User-facing (coins only; timer UI removed)
  final int userCoins;
  final double pricePerSecond;
  final int? remainingSeconds;

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

  // UI-only: show a brief "call ending soon" banner when remainingSeconds <= 10
  final bool showEndingSoonOverlay;

  const CallBillingState({
    this.isActive = false,
    this.callId,
    this.userCoins = 0,
    this.pricePerSecond = 0,
    this.remainingSeconds,
    this.creatorEarnings = 0,
    this.forceEnded = false,
    this.forceEndReason,
    this.settled = false,
    this.finalCoins,
    this.totalDeducted,
    this.totalEarned,
    this.durationSeconds,
    this.showEndingSoonOverlay = false,
  });

  CallBillingState copyWith({
    bool? isActive,
    String? callId,
    int? userCoins,
    double? pricePerSecond,
    int? remainingSeconds,
    double? creatorEarnings,
    bool? forceEnded,
    String? forceEndReason,
    bool? settled,
    int? finalCoins,
    int? totalDeducted,
    int? totalEarned,
    int? durationSeconds,
     bool? showEndingSoonOverlay,
  }) {
    return CallBillingState(
      isActive: isActive ?? this.isActive,
      callId: callId ?? this.callId,
      userCoins: userCoins ?? this.userCoins,
      pricePerSecond: pricePerSecond ?? this.pricePerSecond,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      creatorEarnings: creatorEarnings ?? this.creatorEarnings,
      forceEnded: forceEnded ?? this.forceEnded,
      forceEndReason: forceEndReason ?? this.forceEndReason,
      settled: settled ?? this.settled,
      finalCoins: finalCoins ?? this.finalCoins,
      totalDeducted: totalDeducted ?? this.totalDeducted,
      totalEarned: totalEarned ?? this.totalEarned,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      showEndingSoonOverlay: showEndingSoonOverlay ?? this.showEndingSoonOverlay,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────

class CallBillingNotifier extends StateNotifier<CallBillingState> {
  final Ref _ref;

  CallBillingNotifier(this._ref) : super(const CallBillingState()) {
    _wireSocketCallbacks();
  }

  void _wireSocketCallbacks() {
    final socketService = _ref.read(socketServiceProvider);

    socketService.onBillingStarted = (data) {
      debugPrint('💰 [BILLING] Started: $data');

      // Initialize remainingSeconds from backend if provided (maxSeconds / remainingSeconds)
      final remaining = (data['remainingSeconds'] as num?)?.toInt() ??
          (data['maxSeconds'] as num?)?.toInt();

      state = CallBillingState(
        isActive: true,
        callId: data['callId'] as String?,
        userCoins: (data['coins'] as num?)?.toInt() ?? 0,
        pricePerSecond: (data['pricePerSecond'] as num?)?.toDouble() ?? 0,
        creatorEarnings: (data['earnings'] as num?)?.toDouble() ?? 0,
        remainingSeconds: remaining,
        showEndingSoonOverlay: false,
      );
    };

    socketService.onBillingUpdate = (data) {
      if (!state.isActive) return;

      // Ignore updates for a different call (e.g. delayed event from previous call)
      final eventCallId = data['callId'] as String?;
      if (eventCallId == null || eventCallId != state.callId) {
        debugPrint('💰 [BILLING] Ignoring billing:update for different call: event=$eventCallId current=${state.callId}');
        return;
      }

      final newRemaining =
          (data['remainingSeconds'] as num?)?.toInt() ?? state.remainingSeconds;

      // Determine if we should trigger the "ending soon" overlay (once) when remainingSeconds <= 10
      final shouldShowEndingSoon =
          state.isActive && newRemaining != null && newRemaining <= 10;

      state = state.copyWith(
        userCoins: (data['coins'] as num?)?.toInt() ?? state.userCoins,
        creatorEarnings:
            (data['earnings'] as num?)?.toDouble() ?? state.creatorEarnings,
        remainingSeconds: newRemaining,
        // Only set to true when threshold is met; clearing is handled by UI (2s timer)
        showEndingSoonOverlay:
            shouldShowEndingSoon ? true : state.showEndingSoonOverlay,
      );
    };

    socketService.onBillingSettled = (data) {
      debugPrint('💰 [BILLING] Settled: $data');
      // Only apply settlement for the current call; ignore stale settled from a previous call
      final eventCallId = data['callId'] as String?;
      if (eventCallId == null || eventCallId != state.callId) {
        debugPrint('💰 [BILLING] Ignoring billing:settled for different call: event=$eventCallId current=${state.callId}');
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
      // Only apply force-end for the current call; ignore stale event from a previous call
      final eventCallId = data['callId'] as String?;
      if (eventCallId == null || eventCallId != state.callId) {
        debugPrint('🚨 [BILLING] Ignoring call:force-end for different call: event=$eventCallId current=${state.callId}');
        return;
      }
      state = state.copyWith(
        forceEnded: true,
        forceEndReason: data['reason'] as String?,
      );
    };
  }

  /// Reset billing state (call ended, user dismissed dialogs).
  void reset() {
    state = const CallBillingState();
  }

  /// Clear the "call ending soon" overlay flag (called by UI after 2 seconds).
  void clearEndingSoonOverlay() {
    if (!state.showEndingSoonOverlay) return;
    state = state.copyWith(showEndingSoonOverlay: false);
  }

  @override
  void dispose() {
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
