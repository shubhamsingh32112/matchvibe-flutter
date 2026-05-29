//D:\zztherapy\frontend\lib\features\video\providers\call_billing_provider.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sentry_service.dart';
import '../../../core/services/meta_app_events_service.dart';
import '../../home/providers/availability_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../controllers/call_connection_controller.dart';
import '../services/billing_convergence_metrics.dart';

// ── State ──────────────────────────────────────────────────────────────────
//
// Monetary display and billed elapsed time come only from server `billing:*`
// events. No client-side deduction, earnings math, or local billing timer ticks.

class CallBillingState {
  final BillingRuntimeState runtimeState;
  final String? callId;
  final int billingSequence;
  final String lifecycleState;

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

  /// Welcome intro promo session — spend intro bucket only (server flag).
  final bool introPromoActive;

  /// Last `serverTimestamp` from billing event (ms since epoch).
  final int? lastServerTimestampMs;

  /// Session `callStartTime` from server (ms since epoch).
  final int? callStartTimeMs;

  final String? forceEndReason;
  final int? finalCoins;
  final int? totalDeducted;
  final int? totalEarned;
  final int? durationSeconds;

  // Compatibility wrapper: live-ness is derived from runtime state only.
  bool get isActive =>
      runtimeState == BillingRuntimeState.active ||
      runtimeState == BillingRuntimeState.recovering;
  bool get settled => runtimeState == BillingRuntimeState.settled;
  bool get forceEnded =>
      runtimeState == BillingRuntimeState.ending &&
      forceEndReason != null &&
      forceEndReason!.isNotEmpty;

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
    this.runtimeState = BillingRuntimeState.init,
    this.callId,
    this.billingSequence = 0,
    this.lifecycleState = 'INIT',
    this.userCoins = 0,
    this.creatorEarnings = 0,
    this.elapsedSeconds = 0,
    this.remainingSeconds,
    this.durationLimit,
    this.pricePerSecond,
    this.introPromoActive = false,
    this.lastServerTimestampMs,
    this.callStartTimeMs,
    this.forceEndReason,
    this.finalCoins,
    this.totalDeducted,
    this.totalEarned,
    this.durationSeconds,
  });

  CallBillingState copyWith({
    BillingRuntimeState? runtimeState,
    String? callId,
    int? billingSequence,
    String? lifecycleState,
    int? userCoins,
    double? creatorEarnings,
    int? elapsedSeconds,
    int? remainingSeconds,
    int? durationLimit,
    num? pricePerSecond,
    bool? introPromoActive,
    int? lastServerTimestampMs,
    int? callStartTimeMs,
    bool clearCallStartTimeMs = false,
    String? forceEndReason,
    int? finalCoins,
    int? totalDeducted,
    int? totalEarned,
    int? durationSeconds,
  }) {
    return CallBillingState(
      callId: callId ?? this.callId,
      runtimeState: runtimeState ?? this.runtimeState,
      billingSequence: billingSequence ?? this.billingSequence,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      userCoins: userCoins ?? this.userCoins,
      creatorEarnings: creatorEarnings ?? this.creatorEarnings,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      durationLimit: durationLimit ?? this.durationLimit,
      pricePerSecond: pricePerSecond ?? this.pricePerSecond,
      introPromoActive: introPromoActive ?? this.introPromoActive,
      lastServerTimestampMs:
          lastServerTimestampMs ?? this.lastServerTimestampMs,
      callStartTimeMs: clearCallStartTimeMs
          ? null
          : (callStartTimeMs ?? this.callStartTimeMs),
      forceEndReason: forceEndReason ?? this.forceEndReason,
      finalCoins: finalCoins ?? this.finalCoins,
      totalDeducted: totalDeducted ?? this.totalDeducted,
      totalEarned: totalEarned ?? this.totalEarned,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}

enum BillingRuntimeState {
  init,
  syncing,
  active,
  recovering,
  ending,
  settled,
  failed,
}

/// Terminal runtime states must not accept live billing event resurrection.
bool isBillingTerminalRuntime(BillingRuntimeState runtime) {
  return runtime == BillingRuntimeState.settled ||
      runtime == BillingRuntimeState.failed ||
      runtime == BillingRuntimeState.ending;
}

/// Reject late live events for the same call after terminal convergence.
bool shouldRejectBillingEventForTerminalState({
  required CallBillingState state,
  String? eventCallId,
}) {
  if (!isBillingTerminalRuntime(state.runtimeState)) return false;
  if (eventCallId == null || eventCallId.isEmpty) return true;
  if (state.callId == null || state.callId!.isEmpty) return true;
  return eventCallId == state.callId;
}

/// Alias for terminal runtime checks (ending / settled / failed).
bool isTerminalBillingState(BillingRuntimeState runtime) =>
    isBillingTerminalRuntime(runtime);

/// Reject live billing events after terminal convergence for the same call.
bool shouldRejectEventAfterTerminal({
  required CallBillingState state,
  String? eventCallId,
}) =>
    shouldRejectBillingEventForTerminalState(
      state: state,
      eventCallId: eventCallId,
    );

/// Billing error recovery decision must use pre-error state.
///
/// If the state is converted to `failed` first, terminal guards can block
/// recovery for transient faults.
bool shouldAttemptRecoveryAfterBillingError({
  required CallBillingState priorState,
  required String? eventCallId,
}) {
  return !shouldRejectEventAfterTerminal(
    state: priorState,
    eventCallId: eventCallId,
  );
}

/// Prior billing evidence for reconnect convergence (not `callStartTimeMs`).
bool hadPriorBillingEvidenceForReconnect(CallBillingState state) {
  return state.runtimeState == BillingRuntimeState.active ||
      state.billingSequence > 0;
}

int? _readIntMs(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

/// Tracks the newest recovery envelope applied for this call session.
///
/// Used only for `billing:recover-state:response` ordering — not for
/// `billing:update` / `billing:started` (those keep global sequence gates).
class BillingRecoveryTracking {
  static const int _maxAppliedEnvelopeIds = 32;

  int? latestRecoveryRequestId;
  int? latestGeneratedAtMs;
  String? latestClientRecoveryRequestId;
  final Set<String> appliedRecoveryEnvelopeIds = {};
  final List<String> _appliedEnvelopeOrder = [];

  static String envelopeKey(
    String callId,
    Map<String, dynamic> envelope,
    Map<String, dynamic> entry,
  ) {
    final reqId = envelope['recoveryRequestId'];
    final seq = entry['billingSequence'];
    return '$callId:$reqId:$seq';
  }

  bool hasAppliedEnvelope(String key) =>
      appliedRecoveryEnvelopeIds.contains(key);

  void recordAppliedEnvelope(String key) {
    if (appliedRecoveryEnvelopeIds.contains(key)) return;
    appliedRecoveryEnvelopeIds.add(key);
    _appliedEnvelopeOrder.add(key);
    while (_appliedEnvelopeOrder.length > _maxAppliedEnvelopeIds) {
      final oldest = _appliedEnvelopeOrder.removeAt(0);
      appliedRecoveryEnvelopeIds.remove(oldest);
    }
  }

  void recordApplied(Map<String, dynamic> envelope) {
    final reqId = (envelope['recoveryRequestId'] as num?)?.toInt();
    final genMs = _readIntMs(envelope['generatedAtMs']);
    final clientReqId = envelope['clientRecoveryRequestId']?.toString();
    if (reqId != null && reqId > 0) {
      latestRecoveryRequestId = reqId;
    }
    if (genMs != null && genMs > 0) {
      latestGeneratedAtMs = genMs;
    }
    if (clientReqId != null && clientReqId.isNotEmpty) {
      latestClientRecoveryRequestId = clientReqId;
    }
  }

  void reset() {
    latestRecoveryRequestId = null;
    latestGeneratedAtMs = null;
    latestClientRecoveryRequestId = null;
    appliedRecoveryEnvelopeIds.clear();
    _appliedEnvelopeOrder.clear();
  }
}

/// Pure convergence policy for reconnect/recovery reducers.
///
/// Distributed semantics: equal `billingSequence` on a live socket usually
/// means stale replay, but after reconnect the reducer may sit in `syncing`
/// while the server snapshot is still the authoritative truth at the same
/// sequence — re-hydration must be allowed in that narrow case only.
class BillingConvergencePolicy {
  /// Runtime confidence ordering: ACTIVE > RECOVERING > SYNCING > INIT.
  static int runtimeConfidence(BillingRuntimeState runtime) {
    switch (runtime) {
      case BillingRuntimeState.active:
        return 4;
      case BillingRuntimeState.recovering:
        return 3;
      case BillingRuntimeState.syncing:
        return 2;
      case BillingRuntimeState.init:
        return 1;
      case BillingRuntimeState.ending:
      case BillingRuntimeState.settled:
      case BillingRuntimeState.failed:
        return 0;
    }
  }

  static bool isHigherConfidenceRuntime(
    BillingRuntimeState current,
    BillingRuntimeState incoming,
  ) {
    return runtimeConfidence(incoming) > runtimeConfidence(current);
  }

  static bool isBootstrappingPayload(Map<String, dynamic> envelope) {
    return envelope['status']?.toString() == 'bootstrapping';
  }

  /// Authoritative recover snapshot: server session anchor + live lifecycle.
  ///
  /// `callStartTime` validates payload shape from server — not client reconnect truth.
  static bool isAuthoritativeRecoverPayload(Map<String, dynamic> entry) {
    final startMs = _readIntMs(entry['callStartTime']);
    if (startMs == null || startMs <= 0) return false;
    final lifecycle =
        entry['lifecycleState']?.toString().toUpperCase() ?? '';
    return lifecycle == 'ACTIVE' ||
        lifecycle == 'RECOVERING' ||
        lifecycle == 'SETTLING';
  }

  /// Equal-sequence merge is normally stale replay; allow only when the
  /// reducer is stuck in convergence (`syncing`/`recovering`) and the
  /// recovery snapshot can re-hydrate authoritative billing fields.
  ///
  /// Regression risk: must never run for `billing:update` / `billing:started`.
  static bool canRehydrateEqualSequenceRecover({
    required CallBillingState state,
    required String expectedCallId,
    required Map<String, dynamic> entry,
  }) {
    final seq = (entry['billingSequence'] as num?)?.toInt() ?? 0;
    if (seq <= 0 || seq != state.billingSequence) return false;
    if (state.callId != expectedCallId) return false;
    if (state.runtimeState != BillingRuntimeState.syncing &&
        state.runtimeState != BillingRuntimeState.recovering) {
      return false;
    }
    return isAuthoritativeRecoverPayload(entry);
  }

  /// True when envelope is strictly newer than the last applied recovery.
  static bool recoveryEnvelopeIsNewer({
    required Map<String, dynamic> envelope,
    required BillingRecoveryTracking tracking,
  }) {
    final reqId = (envelope['recoveryRequestId'] as num?)?.toInt();
    final genMs = _readIntMs(envelope['generatedAtMs']);
    final latestReq = tracking.latestRecoveryRequestId;
    final latestGen = tracking.latestGeneratedAtMs;

    if (reqId != null && latestReq != null) {
      if (reqId > latestReq) return true;
      return false;
    }
    if (genMs != null && latestGen != null && genMs > latestGen) {
      return true;
    }
    return latestReq == null && latestGen == null;
  }

  /// True when recover entry fields differ materially from local state.
  static bool recoverFieldsMateriallyDiffer({
    required CallBillingState state,
    required Map<String, dynamic> entry,
  }) {
    final entryCoins = entry['coins'];
    if (entryCoins != null &&
        (entryCoins as num).toInt() != state.userCoins) {
      return true;
    }
    final entryEarnings = entry['earnings'];
    if (entryEarnings != null &&
        (entryEarnings as num).toDouble() != state.creatorEarnings) {
      return true;
    }
    final entryElapsed = entry['elapsedSeconds'];
    if (entryElapsed != null &&
        (entryElapsed as num).toInt() != state.elapsedSeconds) {
      return true;
    }
    final entryTs = _readIntMs(entry['serverTimestamp']);
    if (entryTs != null && entryTs != state.lastServerTimestampMs) {
      return true;
    }
    final entryLifecycle =
        entry['lifecycleState']?.toString().toUpperCase() ?? '';
    if (entryLifecycle.isNotEmpty &&
        entryLifecycle != state.lifecycleState.toUpperCase()) {
      return true;
    }
    final entryRemaining = entry['remainingSeconds'];
    if (entryRemaining != null &&
        state.remainingSeconds != null &&
        (entryRemaining as num).toInt() != state.remainingSeconds) {
      return true;
    }
    return false;
  }

  /// Equal-sequence recover while ACTIVE: convergence refresh, not replay.
  static bool shouldApplyEqualSequenceRefresh({
    required CallBillingState state,
    required String expectedCallId,
    required Map<String, dynamic> envelope,
    required Map<String, dynamic> entry,
    required BillingRecoveryTracking tracking,
  }) {
    final seq = (entry['billingSequence'] as num?)?.toInt() ?? 0;
    if (seq <= 0 || seq != state.billingSequence) return false;
    if (state.callId != expectedCallId) return false;
    if (state.runtimeState != BillingRuntimeState.active) return false;
    if (isTerminalBillingState(state.runtimeState)) return false;
    final lifecycle = entry['lifecycleState']?.toString().toUpperCase() ?? '';
    if (lifecycle != 'ACTIVE') return false;
    if (!isAuthoritativeRecoverPayload(entry)) return false;
    if (!recoveryEnvelopeIsNewer(envelope: envelope, tracking: tracking)) {
      return false;
    }
    return recoverFieldsMateriallyDiffer(state: state, entry: entry);
  }

  /// Reject delayed/out-of-order/duplicate recovery envelopes.
  ///
  /// Applies only to recovery responses — not billing tick updates.
  static bool isOlderRecoveryResponse({
    required Map<String, dynamic> envelope,
    required BillingRecoveryTracking tracking,
  }) {
    final reqId = (envelope['recoveryRequestId'] as num?)?.toInt();
    final genMs = _readIntMs(envelope['generatedAtMs']);
    final latestReq = tracking.latestRecoveryRequestId;
    final latestGen = tracking.latestGeneratedAtMs;

    if (reqId != null && latestReq != null) {
      if (reqId < latestReq) return true;
      if (reqId == latestReq) return true;
    }
    if (genMs != null && latestGen != null && genMs < latestGen) {
      return true;
    }
    return false;
  }

  /// Bootstrapping / lower-confidence recover must not regress ACTIVE.
  static bool shouldPreventActiveDowngrade({
    required CallBillingState state,
    required BillingRuntimeState targetRuntime,
  }) {
    return runtimeConfidence(state.runtimeState) >
        runtimeConfidence(targetRuntime);
  }

  /// `billing:update` may promote `syncing` → `active` when authoritative.
  static bool canPromoteFromUpdate({
    required CallBillingState state,
    required Map<String, dynamic> data,
  }) {
    if (state.runtimeState != BillingRuntimeState.syncing &&
        state.runtimeState != BillingRuntimeState.recovering) {
      return false;
    }
    final eventCallId = data['callId'] as String?;
    if (eventCallId == null ||
        eventCallId.isEmpty ||
        eventCallId != state.callId) {
      return false;
    }
    final incoming = (data['billingSequence'] as num?)?.toInt() ?? 0;
    if (incoming > 0 && incoming < state.billingSequence) return false;
    final hasCoins = data['coins'] != null;
    final hasElapsed = data['elapsedSeconds'] != null;
    final hasTs = _readIntMs(data['serverTimestamp']) != null;
    if (!hasCoins && !(hasElapsed && hasTs)) return false;
    final lifecycle =
        data['lifecycleState']?.toString().toUpperCase() ?? 'ACTIVE';
    if (lifecycle == 'SETTLED' || lifecycle == 'ENDED') return false;
    return true;
  }

  /// Global stale gate for non-recovery events (strict `<=`).
  static bool shouldRejectStaleEventSequence({
    required CallBillingState state,
    required Map<String, dynamic> data,
  }) {
    final incoming = (data['billingSequence'] as num?)?.toInt() ?? 0;
    if (incoming <= 0) {
      return state.billingSequence > 0;
    }
    return incoming <= state.billingSequence;
  }

  /// Recovery merge sequence gate: reject lower; equal only via rehydrate/refresh.
  static bool shouldRejectRecoverMergeSequence({
    required CallBillingState state,
    required Map<String, dynamic> entry,
    required String expectedCallId,
    required Map<String, dynamic> envelope,
    required BillingRecoveryTracking tracking,
  }) {
    final seq = (entry['billingSequence'] as num?)?.toInt() ?? 0;
    if (seq <= 0) return false;
    if (seq < state.billingSequence) return true;
    if (seq > state.billingSequence) return false;
    if (canRehydrateEqualSequenceRecover(
      state: state,
      expectedCallId: expectedCallId,
      entry: entry,
    )) {
      return false;
    }
    if (shouldApplyEqualSequenceRefresh(
      state: state,
      expectedCallId: expectedCallId,
      envelope: envelope,
      entry: entry,
      tracking: tracking,
    )) {
      return false;
    }
    return true;
  }

  /// Equal-seq recover blocked on ACTIVE because snapshot matches local fields.
  static bool isActiveEqualSeqRejectedNoMaterialChange({
    required CallBillingState state,
    required String expectedCallId,
    required Map<String, dynamic> envelope,
    required Map<String, dynamic> entry,
    required BillingRecoveryTracking tracking,
  }) {
    final seq = (entry['billingSequence'] as num?)?.toInt() ?? 0;
    if (seq <= 0 || seq != state.billingSequence) return false;
    if (state.runtimeState != BillingRuntimeState.active) return false;
    if (state.callId != expectedCallId) return false;
    final lifecycle = entry['lifecycleState']?.toString().toUpperCase() ?? '';
    if (lifecycle != 'ACTIVE') return false;
    if (!isAuthoritativeRecoverPayload(entry)) return false;
    if (!recoveryEnvelopeIsNewer(envelope: envelope, tracking: tracking)) {
      return false;
    }
    return !recoverFieldsMateriallyDiffer(state: state, entry: entry);
  }
}

/// Result of applying a recovery envelope (for tests and reducer).
enum BillingRecoveryApplyOutcome {
  applied,
  rejectedOlder,
  rejectedDowngrade,
  rejectedStaleSequence,
  rejectedNotAuthoritative,
  rejectedNotSuccess,
  bootstrapping,
  duplicate,
  rejectedNoMaterialChange,
}

class BillingRecoveryMergeResult {
  final CallBillingState state;
  final BillingRecoveryApplyOutcome outcome;
  final BillingRecoveryTracking tracking;

  const BillingRecoveryMergeResult({
    required this.state,
    required this.outcome,
    required this.tracking,
  });
}

/// Deterministic recovery merge used by [CallBillingNotifier.mergeRecoverPayload].
class BillingRecoveryMerge {
  static BillingRecoveryMergeResult apply({
    required CallBillingState state,
    required BillingRecoveryTracking tracking,
    required Map<String, dynamic> envelope,
    required String expectedCallId,
  }) {
    final ok = envelope['success'] == true;
    if (!ok) {
      return BillingRecoveryMergeResult(
        state: state,
        outcome: BillingRecoveryApplyOutcome.rejectedNotSuccess,
        tracking: tracking,
      );
    }

    final status = envelope['status']?.toString();
    if (status == 'bootstrapping') {
      if (BillingConvergencePolicy.isOlderRecoveryResponse(
        envelope: envelope,
        tracking: tracking,
      )) {
        return BillingRecoveryMergeResult(
          state: state,
          outcome: BillingRecoveryApplyOutcome.rejectedOlder,
          tracking: tracking,
        );
      }
      if (BillingConvergencePolicy.shouldPreventActiveDowngrade(
        state: state,
        targetRuntime: BillingRuntimeState.syncing,
      )) {
        return BillingRecoveryMergeResult(
          state: state,
          outcome: BillingRecoveryApplyOutcome.rejectedDowngrade,
          tracking: tracking,
        );
      }
      tracking.recordApplied(envelope);
      return BillingRecoveryMergeResult(
        state: state.copyWith(
          runtimeState: BillingRuntimeState.syncing,
          callId: expectedCallId,
        ),
        outcome: BillingRecoveryApplyOutcome.bootstrapping,
        tracking: tracking,
      );
    }

    final list = envelope['activeCalls'];
    if (list is! List || list.isEmpty) {
      return BillingRecoveryMergeResult(
        state: state,
        outcome: BillingRecoveryApplyOutcome.rejectedNotSuccess,
        tracking: tracking,
      );
    }

    Map<String, dynamic>? entry;
    for (final item in list) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(
        item.map((k, v) => MapEntry(k.toString(), v)),
      );
      if (map['callId'] == expectedCallId) {
        entry = map;
        break;
      }
    }
    if (entry == null) {
      return BillingRecoveryMergeResult(
        state: state,
        outcome: BillingRecoveryApplyOutcome.rejectedNotSuccess,
        tracking: tracking,
      );
    }

    final envelopeKey = BillingRecoveryTracking.envelopeKey(
      expectedCallId,
      envelope,
      entry,
    );
    if (tracking.hasAppliedEnvelope(envelopeKey)) {
      return BillingRecoveryMergeResult(
        state: state,
        outcome: BillingRecoveryApplyOutcome.duplicate,
        tracking: tracking,
      );
    }

    if (BillingConvergencePolicy.isOlderRecoveryResponse(
      envelope: envelope,
      tracking: tracking,
    )) {
      final reqId = (envelope['recoveryRequestId'] as num?)?.toInt();
      if (reqId != null && reqId == tracking.latestRecoveryRequestId) {
        return BillingRecoveryMergeResult(
          state: state,
          outcome: BillingRecoveryApplyOutcome.duplicate,
          tracking: tracking,
        );
      }
      return BillingRecoveryMergeResult(
        state: state,
        outcome: BillingRecoveryApplyOutcome.rejectedOlder,
        tracking: tracking,
      );
    }

    if (BillingConvergencePolicy.isActiveEqualSeqRejectedNoMaterialChange(
      state: state,
      expectedCallId: expectedCallId,
      envelope: envelope,
      entry: entry,
      tracking: tracking,
    )) {
      return BillingRecoveryMergeResult(
        state: state,
        outcome: BillingRecoveryApplyOutcome.rejectedNoMaterialChange,
        tracking: tracking,
      );
    }

    if (BillingConvergencePolicy.shouldRejectRecoverMergeSequence(
      state: state,
      entry: entry,
      expectedCallId: expectedCallId,
      envelope: envelope,
      tracking: tracking,
    )) {
      return BillingRecoveryMergeResult(
        state: state,
        outcome: BillingRecoveryApplyOutcome.rejectedStaleSequence,
        tracking: tracking,
      );
    }

    if (!BillingConvergencePolicy.isAuthoritativeRecoverPayload(entry)) {
      return BillingRecoveryMergeResult(
        state: state,
        outcome: BillingRecoveryApplyOutcome.rejectedNotAuthoritative,
        tracking: tracking,
      );
    }

    final coins = (entry['coins'] as num?)?.toInt() ?? state.userCoins;
    final earnings =
        (entry['earnings'] as num?)?.toDouble() ?? state.creatorEarnings;
    final elapsed =
        (entry['elapsedSeconds'] as num?)?.toInt() ?? state.elapsedSeconds;
    final remaining = (entry['remainingSeconds'] as num?)?.toInt();
    final pricePerSecond = entry['pricePerSecond'] as num? ?? state.pricePerSecond;
    final serverTs = _readIntMs(entry['serverTimestamp']);
    final startMs = _readIntMs(entry['callStartTime']);
    final seq = (entry['billingSequence'] as num?)?.toInt() ?? 0;
    final lifecycleState =
        entry['lifecycleState']?.toString() ?? state.lifecycleState;

    tracking.recordApplied(envelope);
    tracking.recordAppliedEnvelope(envelopeKey);
    final merged = state.copyWith(
      runtimeState: BillingRuntimeState.active,
      callId: expectedCallId,
      billingSequence: seq > 0 ? seq : state.billingSequence,
      lifecycleState: lifecycleState,
      userCoins: coins,
      creatorEarnings: earnings,
      elapsedSeconds: elapsed,
      remainingSeconds: remaining ?? state.remainingSeconds,
      pricePerSecond: pricePerSecond,
      lastServerTimestampMs: serverTs ?? state.lastServerTimestampMs,
      callStartTimeMs: startMs ?? state.callStartTimeMs,
    );
    return BillingRecoveryMergeResult(
      state: merged,
      outcome: BillingRecoveryApplyOutcome.applied,
      tracking: tracking,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────

class CallBillingNotifier extends StateNotifier<CallBillingState> {
  final Ref _ref;

  late final void Function() _onSocketReconnected;
  Timer? _billingRecoveryRetryTimer;
  int _billingRecoveryAttempts = 0;
  static const int _maxBillingRecoveryAttempts = 10;
  static const Duration _suppressedRecoveryRetryDelay = Duration(
    milliseconds: 900,
  );
  static const Duration _billingStuckEndGrace = Duration(seconds: 20);
  Timer? _connectedWithoutBillingTimer;
  DateTime? _connectedStuckSince;
  DateTime? _lastOrphanRecoveryEmit;
  bool _syncWarningReportedForCurrentCall = false;
  bool _stuckEndRequested = false;
  final BillingRecoveryTracking _recoveryTracking = BillingRecoveryTracking();

  CallBillingNotifier(this._ref) : super(const CallBillingState()) {
    _onSocketReconnected = () {
      if (shouldRejectEventAfterTerminal(
        state: state,
        eventCallId: state.callId,
      )) {
        return;
      }
      requestBillingRecoveryForActiveCall();
      _ref
          .read(callConnectionControllerProvider.notifier)
          .retryBillingStartIfNeeded();
      _startBillingRecoveryRetry();
    };
    _wireSocketCallbacks();
    _connectedWithoutBillingTimer = Timer.periodic(const Duration(seconds: 1), (
      _,
    ) {
      _onConnectedWithoutBillingWatchTick();
    });
  }

  int _readSequence(Map<String, dynamic> data) =>
      (data['billingSequence'] as num?)?.toInt() ?? 0;

  void _logRecoveryDrop(
    String reason, {
    String? expectedCallId,
    Map<String, dynamic>? payload,
  }) {
    SentryService.addThrottledBreadcrumb(
      category: 'billing.recover',
      message: 'billing_recover_drop',
      data: {
        'reason': reason,
        ...?expectedCallId == null
            ? null
            : {'expected_call_id': expectedCallId},
        if (payload != null) 'status': payload['status']?.toString(),
        if (payload != null) 'response_reason': payload['reason']?.toString(),
        if (payload != null)
          'recovery_outcome': payload['recoveryOutcome']?.toString(),
        if (payload != null)
          'client_recovery_request_id':
              payload['clientRecoveryRequestId']?.toString(),
      },
    );
  }

  void _recordRecoveryOutcomeTag(Map<String, dynamic> data) {
    final outcome = data['recoveryOutcome']?.toString();
    if (outcome == null || outcome.isEmpty) return;
    SentryService.addThrottledBreadcrumb(
      category: 'billing.recover',
      message: 'billing_recovery_outcome',
      data: {
        'recovery_outcome': outcome,
        'status': data['status']?.toString(),
        'reason': data['reason']?.toString(),
      },
    );
  }

  void _recordClientRecoveryOutcome(String outcome, {String? reason}) {
    SentryService.addThrottledBreadcrumb(
      category: 'billing.recover',
      message: 'billing_recovery_outcome_client',
      data: {
        'recovery_outcome': outcome,
        ...?reason == null ? null : {'reason': reason},
      },
    );
  }

  void _addConvergenceBreadcrumb(String message, {Map<String, Object?>? data}) {
    SentryService.addThrottledBreadcrumb(
      category: 'billing.convergence',
      message: message,
      data: data,
    );
  }

  bool _canPromoteFromUpdate(Map<String, dynamic> data) =>
      BillingConvergencePolicy.canPromoteFromUpdate(state: state, data: data);

  bool _shouldIgnoreStaleBySequence(Map<String, dynamic> data) {
    final stale = BillingConvergencePolicy.shouldRejectStaleEventSequence(
      state: state,
      data: data,
    );
    if (stale) {
      _recordClientRecoveryOutcome('recover_stale_sequence', reason: 'sequence_gate');
      _logRecoveryDrop(
        'stale_sequence',
        expectedCallId: state.callId,
        payload: data,
      );
    }
    return stale;
  }

  /// Connected call without live billing: prefer `recovering` and drop stale anchors.
  void _enterReconnectConvergenceWait() {
    final hadPriorBillingEvidence = hadPriorBillingEvidenceForReconnect(state);
    if (hadPriorBillingEvidence) {
      if (state.runtimeState != BillingRuntimeState.recovering) {
        state = state.copyWith(
          runtimeState: BillingRuntimeState.recovering,
          clearCallStartTimeMs: true,
        );
      }
      return;
    }
    if (state.runtimeState == BillingRuntimeState.init) {
      state = state.copyWith(runtimeState: BillingRuntimeState.syncing);
      return;
    }
    if (state.runtimeState != BillingRuntimeState.syncing &&
        state.runtimeState != BillingRuntimeState.recovering) {
      state = state.copyWith(runtimeState: BillingRuntimeState.syncing);
    }
  }

  bool _rejectIfTerminalLiveEvent(
    Map<String, dynamic> data, {
    required String eventKind,
  }) {
    final eventCallId = data['callId'] as String?;
    if (!shouldRejectEventAfterTerminal(
      state: state,
      eventCallId: eventCallId,
    )) {
      return false;
    }
    debugPrint(
      '💰 [BILLING] Ignoring $eventKind — terminal runtime (${state.runtimeState.name}) callId=${state.callId}',
    );
    _logRecoveryDrop('terminal_runtime_reject', payload: data);
    return true;
  }

  void _startBillingRecoveryRetry() {
    _billingRecoveryRetryTimer?.cancel();
    _billingRecoveryAttempts = 0;
    _requestBillingRecoveryWithBackoff();
  }

  void _requestBillingRecoveryWithBackoff() {
    if (shouldRejectEventAfterTerminal(
      state: state,
      eventCallId: state.callId,
    )) {
      _stopBillingRecoveryRetry();
      return;
    }
    final isLive =
        state.runtimeState == BillingRuntimeState.active ||
        state.runtimeState == BillingRuntimeState.recovering;
    if (isLive) return;
    if (_billingRecoveryAttempts >= _maxBillingRecoveryAttempts) {
      debugPrint(
        '💰 [BILLING] billing_recovery_failed attempts=$_billingRecoveryAttempts callId=${state.callId}',
      );
      return;
    }
    _billingRecoveryAttempts += 1;
    BillingConvergenceMetrics.instance.onRecoverRetry();
    final socketService = _ref.read(socketServiceProvider);
    debugPrint(
      '💰 [BILLING] billing_recovery_requested attempt=$_billingRecoveryAttempts callId=${state.callId}',
    );
    socketService.requestBillingStateRecovery(
      callId: state.callId,
      phase: 'backoff_retry',
    );

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
    final conn = _ref.read(callConnectionControllerProvider);
    final phase = conn.phase;
    if (phase != CallConnectionPhase.connected) {
      _connectedStuckSince = null;
      _syncWarningReportedForCurrentCall = false;
      _stuckEndRequested = false;
      _lastOrphanRecoveryEmit = null;
      return;
    }
    if (shouldRejectEventAfterTerminal(
      state: state,
      eventCallId: state.callId,
    )) {
      return;
    }
    final isLive =
        state.runtimeState == BillingRuntimeState.active ||
        state.runtimeState == BillingRuntimeState.recovering;
    if (isLive) {
      _connectedStuckSince = null;
      _syncWarningReportedForCurrentCall = false;
      _stuckEndRequested = false;
      _lastOrphanRecoveryEmit = null;
      return;
    }
    _enterReconnectConvergenceWait();

    final activeCallId = conn.call?.id;
    if (activeCallId != null &&
        activeCallId.isNotEmpty &&
        state.callId != activeCallId) {
      state = state.copyWith(callId: activeCallId);
    }

    _connectedStuckSince ??= DateTime.now();
    final stuckFor = DateTime.now().difference(_connectedStuckSince!);
    if (activeCallId != null &&
        activeCallId.isNotEmpty &&
        stuckFor >= const Duration(seconds: 6) &&
        !_syncWarningReportedForCurrentCall) {
      _syncWarningReportedForCurrentCall = true;
      final stuckSeconds = stuckFor.inSeconds;
      final socketService = _ref.read(socketServiceProvider);
      socketService.emitBillingSyncWarning(
        callId: activeCallId,
        stuckSeconds: stuckSeconds,
        phase: phase.name,
      );
      SentryService.addThrottledBreadcrumb(
        category: 'billing.sync',
        message: 'billing_syncing_stuck',
        data: {
          'call_id': activeCallId,
          'stuck_seconds': stuckSeconds,
          'phase': phase.name,
        },
      );
      unawaited(
        SentryService.captureMessage(
          'Billing syncing stuck during active call',
          tags: {
            'issue': 'billing_syncing_stuck',
            'call_id': activeCallId,
            'phase': phase.name,
            'stuck_seconds': '$stuckSeconds',
          },
        ),
      );
    }

    if (stuckFor > const Duration(milliseconds: 1500)) {
      final now = DateTime.now();
      if (_lastOrphanRecoveryEmit == null ||
          now.difference(_lastOrphanRecoveryEmit!) >
              const Duration(seconds: 2)) {
        _lastOrphanRecoveryEmit = now;
        requestBillingRecoveryForActiveCall();
      }
    }
    if (stuckFor > _billingStuckEndGrace && !_stuckEndRequested) {
      _stuckEndRequested = true;
      debugPrint(
        '💰 [BILLING] billing_stuck_ending_call no_active_billing after ${stuckFor.inSeconds}s',
      );
      unawaited(_ref.read(callConnectionControllerProvider.notifier).endCall());
    } else if (stuckFor > const Duration(seconds: 8) &&
        _billingRecoveryAttempts < _maxBillingRecoveryAttempts) {
      _startBillingRecoveryRetry();
    }
  }

  /// Ask the server for Redis billing snapshot (uses active call id when known).
  void requestBillingRecoveryForActiveCall() {
    final conn = _ref.read(callConnectionControllerProvider);
    final activeCallId = conn.call?.id;
    if (activeCallId != null && activeCallId.isNotEmpty) {
      state = state.copyWith(callId: activeCallId);
    }
    if (shouldRejectEventAfterTerminal(
      state: state,
      eventCallId: activeCallId ?? state.callId,
    )) {
      return;
    }
    BillingConvergenceMetrics.instance.onRecoverRequest();
    final socketService = _ref.read(socketServiceProvider);
    socketService.requestBillingStateRecovery(
      callId: activeCallId,
      phase: conn.phase.name,
    );

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

  void _wireSocketCallbacks() {
    final socketService = _ref.read(socketServiceProvider);
    socketService.onReconnected = _onSocketReconnected;

    socketService.onBillingStarted = (data) {
      applyBillingStartedPayload(data);
    };

    socketService.onBillingError = (data) {
      debugPrint('❌ [BILLING] billing:error: $data');
      if (_rejectIfTerminalLiveEvent(data, eventKind: 'billing:error')) return;
      final shouldRecover = shouldAttemptRecoveryAfterBillingError(
        priorState: state,
        eventCallId: data['callId'] as String?,
      );
      state = state.copyWith(runtimeState: BillingRuntimeState.failed);
      if (shouldRecover) {
        requestBillingRecoveryForActiveCall();
        _startBillingRecoveryRetry();
      }
    };

    socketService.onBillingUpdate = (data) {
      if (_rejectIfTerminalLiveEvent(data, eventKind: 'billing:update')) return;
      final promote = _canPromoteFromUpdate(data);
      if (!promote && _shouldIgnoreStaleBySequence(data)) return;
      if (!promote &&
          (state.runtimeState == BillingRuntimeState.init ||
              state.runtimeState == BillingRuntimeState.syncing)) {
        return;
      }

      final eventCallId = data['callId'] as String?;
      if (eventCallId == null || eventCallId != state.callId) {
        debugPrint(
          '💰 [BILLING] Ignoring billing:update for different call: event=$eventCallId current=${state.callId}',
        );
        return;
      }

      final coins = (data['coins'] as num?)?.toInt();
      final earnings = (data['earnings'] as num?)?.toDouble();
      final elapsed = (data['elapsedSeconds'] as num?)?.toInt();
      final remaining = (data['remainingSeconds'] as num?)?.toInt();
      final durationLimit = (data['durationLimit'] as num?)?.toInt();
      final serverTs = _readIntMs(data['serverTimestamp']);
      final startMs = _readIntMs(data['callStartTime']);
      final lifecycleState =
          data['lifecycleState']?.toString() ?? state.lifecycleState;
      final seq = _readSequence(data);

      if (promote) {
        _addConvergenceBreadcrumb(
          'syncing_promoted_by_update',
          data: {
            'call_id': eventCallId,
            'billing_sequence': seq,
          },
        );
      }

      final keepLiveRemaining = !_isTerminalCallState();
      state = state.copyWith(
        runtimeState: BillingRuntimeState.active,
        billingSequence: seq > 0 ? seq : state.billingSequence,
        lifecycleState: lifecycleState,
        userCoins: coins ?? state.userCoins,
        creatorEarnings: earnings ?? state.creatorEarnings,
        elapsedSeconds: elapsed ?? state.elapsedSeconds,
        remainingSeconds: _coerceRemainingSeconds(
          incoming: remaining,
          fallback: state.remainingSeconds,
          keepLiveRemainingOnZero: keepLiveRemaining,
        ),
        durationLimit: durationLimit ?? state.durationLimit,
        lastServerTimestampMs: serverTs ?? state.lastServerTimestampMs,
        callStartTimeMs: startMs ?? state.callStartTimeMs,
      );
      if (promote) {
        _stopBillingRecoveryRetry();
      }
    };

    socketService.onBillingSettled = (data) {
      debugPrint('💰 [BILLING] Settled: $data');
      if (_shouldIgnoreStaleBySequence(data)) return;
      final eventCallId = data['callId'] as String?;
      if (eventCallId == null || eventCallId != state.callId) {
        debugPrint(
          '💰 [BILLING] Ignoring billing:settled for different call: event=$eventCallId current=${state.callId}',
        );
        return;
      }
      if (_isCallStillJoinedOrConnected()) {
        debugPrint(
          '⚠️ [BILLING] Ignoring premature settled state while call is still joined/connected: callId=$eventCallId',
        );
        SentryService.addThrottledBreadcrumb(
          category: 'billing.convergence',
          message: 'premature_settled_ignored_joined',
          data: {'call_id': eventCallId},
        );
        return;
      }
      final totalDeducted = (data['totalDeducted'] as num?)?.toInt() ?? 0;
      state = state.copyWith(
        runtimeState: BillingRuntimeState.settled,
        billingSequence: _readSequence(data) > 0
            ? _readSequence(data)
            : state.billingSequence,
        lifecycleState: 'SETTLED',
        finalCoins: (data['finalCoins'] as num?)?.toInt(),
        totalDeducted: totalDeducted,
        totalEarned: (data['totalEarned'] as num?)?.toInt(),
        durationSeconds: (data['durationSeconds'] as num?)?.toInt(),
      );
      if (totalDeducted > 0) {
        MetaAppEventsService.logSpendCredits(
          contentId: eventCallId,
          amount: totalDeducted.toDouble(),
          contentType: 'video_call',
        );
      }
    };

    socketService.onCallForceEnd = (data) {
      debugPrint('🚨 [BILLING] Force end: $data');
      final eventCallId = data['callId'] as String?;
      if (eventCallId == null || eventCallId != state.callId) {
        debugPrint(
          '🚨 [BILLING] Ignoring call:force-end for different call: event=$eventCallId current=${state.callId}',
        );
        return;
      }
      state = state.copyWith(
        runtimeState: BillingRuntimeState.ending,
        lifecycleState: 'ENDING',
        forceEndReason: data['reason'] as String?,
      );
    };

    socketService.onBillingRecoverState = _onBillingRecoverState;
  }

  void applyBillingStartedPayload(Map<String, dynamic> data) {
    debugPrint('💰 [BILLING] Started: $data');
    if (_rejectIfTerminalLiveEvent(data, eventKind: 'billing:started')) return;
    if (_shouldIgnoreStaleBySequence(data)) return;
    _stopBillingRecoveryRetry();
    final callId = data['callId'] as String?;
    final coins = (data['coins'] as num?)?.toInt();
    final earnings = (data['earnings'] as num?)?.toDouble();
    final maxSeconds = (data['maxSeconds'] as num?)?.toInt();
    final elapsed = (data['elapsedSeconds'] as num?)?.toInt() ?? 0;
    final remainingFromPayload = (data['remainingSeconds'] as num?)?.toInt();
    final pricePerSecond = data['pricePerSecond'] as num?;
    final introPromoActive = data['introPromoActive'] == true;
    final serverTs = _readIntMs(data['serverTimestamp']);
    final startMs = _readIntMs(data['callStartTime']);
    final durationLimit = (data['durationLimit'] as num?)?.toInt();
    final seq = _readSequence(data);
    final lifecycleState = data['lifecycleState']?.toString() ?? 'ACTIVE';

    final remainingValue = _coerceRemainingSeconds(
      incoming: remainingFromPayload,
      fallback: maxSeconds,
      keepLiveRemainingOnZero: true,
    );
    state = CallBillingState(
      runtimeState: BillingRuntimeState.active,
      callId: callId,
      billingSequence: seq > 0 ? seq : state.billingSequence,
      lifecycleState: lifecycleState,
      userCoins: coins ?? 0,
      creatorEarnings: earnings ?? 0,
      elapsedSeconds: elapsed,
      remainingSeconds: remainingValue,
      durationLimit: durationLimit,
      pricePerSecond: pricePerSecond,
      introPromoActive: introPromoActive,
      lastServerTimestampMs: serverTs,
      callStartTimeMs: startMs,
    );
  }

  void _onBillingRecoverState(Map<String, dynamic> data) {
    _recordRecoveryOutcomeTag(data);
    final status = data['status']?.toString();
    if (status == 'suppressed') {
      _recordClientRecoveryOutcome('recover_suppressed', reason: 'suppressed');
      _logRecoveryDrop('suppressed', payload: data);
      _billingRecoveryRetryTimer?.cancel();
      _billingRecoveryRetryTimer = Timer(_suppressedRecoveryRetryDelay, () {
        requestBillingRecoveryForActiveCall();
      });
      return;
    }
    if (status == 'no_active_call') {
      final conn = _ref.read(callConnectionControllerProvider);
      if (conn.phase == CallConnectionPhase.connected) {
        _recordClientRecoveryOutcome('recover_empty', reason: 'no_active_call_connected');
        _logRecoveryDrop('no_active_call_while_connected', payload: data);
        _startBillingRecoveryRetry();
      }
      return;
    }
    if (status == 'terminal_settled') {
      final list = data['activeCalls'];
      if (list is List && list.isNotEmpty && list.first is Map) {
        final entry = Map<String, dynamic>.from(list.first as Map);
        final callId = entry['callId']?.toString();
        if (callId != null &&
            callId.isNotEmpty &&
            (state.callId == null || state.callId == callId)) {
          if (_isCallStillJoinedOrConnected()) {
            debugPrint(
              '⚠️ [BILLING] Ignoring terminal_settled recovery while call still connected: callId=$callId',
            );
            return;
          }
          final seq = _readSequence(entry);
          state = state.copyWith(
            runtimeState: BillingRuntimeState.settled,
            callId: callId,
            billingSequence: seq > 0 ? seq : state.billingSequence,
            lifecycleState: 'SETTLED',
            finalCoins: (entry['finalCoins'] as num?)?.toInt(),
            totalDeducted: (entry['totalDeducted'] as num?)?.toInt(),
            totalEarned: (entry['totalEarned'] as num?)?.toInt(),
            durationSeconds: (entry['durationSeconds'] as num?)?.toInt(),
          );
          return;
        }
      }
      _startBillingRecoveryRetry();
      return;
    }

    var expected = state.callId;
    if (expected == null) {
      final list = data['activeCalls'];
      if (list is List && list.length == 1 && list.first is Map) {
        expected = (list.first as Map)['callId']?.toString();
      }
    }
    if (expected == null || expected.isEmpty) {
      debugPrint('💰 [BILLING] Recover skipped — could not resolve callId');
      _logRecoveryDrop('missing_expected_call_id', payload: data);
      return;
    }
    mergeRecoverPayload(data, expectedCallId: expected);
  }

  /// Apply `billing:recover-state:response` for [expectedCallId] (e.g. from controller when state.callId is not yet set).
  void mergeRecoverPayload(
    Map<String, dynamic> data, {
    required String expectedCallId,
  }) {
    if (shouldRejectEventAfterTerminal(
      state: state,
      eventCallId: expectedCallId,
    )) {
      _logRecoveryDrop(
        'terminal_runtime_reject',
        expectedCallId: expectedCallId,
        payload: data,
      );
      return;
    }
    final ok = data['success'] == true;
    if (!ok) {
      _recordClientRecoveryOutcome('recover_emit_skipped', reason: 'recover_not_success');
      _logRecoveryDrop('recover_not_success', expectedCallId: expectedCallId, payload: data);
      return;
    }
    final status = data['status']?.toString();
    if (status == 'invalid_tuple') {
      _recordClientRecoveryOutcome('recover_tuple_invalid', reason: 'status_invalid_tuple');
      _logRecoveryDrop('invalid_tuple', expectedCallId: expectedCallId, payload: data);
      _startBillingRecoveryRetry();
      return;
    }

    final mergeResult = BillingRecoveryMerge.apply(
      state: state,
      tracking: _recoveryTracking,
      envelope: data,
      expectedCallId: expectedCallId,
    );

    switch (mergeResult.outcome) {
      case BillingRecoveryApplyOutcome.bootstrapping:
        _recordClientRecoveryOutcome('recover_bootstrapping', reason: 'status_bootstrapping');
        state = mergeResult.state;
        _logRecoveryDrop('bootstrapping_wait', expectedCallId: expectedCallId, payload: data);
        _startBillingRecoveryRetry();
        return;
      case BillingRecoveryApplyOutcome.rejectedOlder:
        _addConvergenceBreadcrumb(
          'recovery_order_rejected',
          data: {'call_id': expectedCallId},
        );
        _addConvergenceBreadcrumb(
          'stale_recovery_rejected',
          data: {'call_id': expectedCallId},
        );
        _logRecoveryDrop(
          'stale_recovery_response',
          expectedCallId: expectedCallId,
          payload: data,
        );
        return;
      case BillingRecoveryApplyOutcome.rejectedDowngrade:
        _addConvergenceBreadcrumb(
          'active_downgrade_prevented',
          data: {'status': status},
        );
        _addConvergenceBreadcrumb(
          'recovery_confidence_rejected',
          data: {'status': status},
        );
        _logRecoveryDrop(
          'bootstrapping_downgrade_blocked',
          expectedCallId: expectedCallId,
          payload: data,
        );
        return;
      case BillingRecoveryApplyOutcome.duplicate:
        BillingConvergenceMetrics.instance.onRecoverDuplicate();
        return;
      case BillingRecoveryApplyOutcome.rejectedNoMaterialChange:
        return;
      case BillingRecoveryApplyOutcome.rejectedStaleSequence:
        _recordClientRecoveryOutcome('recover_stale_sequence', reason: 'merge_gate');
        _logRecoveryDrop(
          'stale_sequence_merge_drop',
          expectedCallId: expectedCallId,
          payload: data,
        );
        return;
      case BillingRecoveryApplyOutcome.rejectedNotAuthoritative:
        _logRecoveryDrop(
          'recover_not_authoritative',
          expectedCallId: expectedCallId,
          payload: data,
        );
        return;
      case BillingRecoveryApplyOutcome.rejectedNotSuccess:
        if (status != 'bootstrapping') {
          _recordClientRecoveryOutcome('recover_empty', reason: 'empty_payload');
          _logRecoveryDrop('empty_active_calls', expectedCallId: expectedCallId, payload: data);
          _startBillingRecoveryRetry();
        } else {
          _logRecoveryDrop('call_id_mismatch', expectedCallId: expectedCallId, payload: data);
        }
        return;
      case BillingRecoveryApplyOutcome.applied:
        final seq = mergeResult.state.billingSequence;
        final priorRuntime = state.runtimeState;
        if (seq > 0 && seq == state.billingSequence) {
          if (priorRuntime == BillingRuntimeState.active) {
            _addConvergenceBreadcrumb(
              'equal_sequence_active_refresh',
              data: {
                'call_id': expectedCallId,
                'billing_sequence': seq,
              },
            );
          } else {
            _addConvergenceBreadcrumb(
              'equal_sequence_rehydrate_allowed',
              data: {
                'call_id': expectedCallId,
                'billing_sequence': seq,
              },
            );
          }
        }
        state = _freezeRemainingIfZero(mergeResult.state);
        _stopBillingRecoveryRetry();
        BillingConvergenceMetrics.instance.onRecoverApplied();
        _recordClientRecoveryOutcome('recover_success', reason: 'merge_applied');
        debugPrint(
          '💰 [BILLING] billing_recovery_succeeded callId=$expectedCallId',
        );
        debugPrint('💰 [BILLING] Recovered state for call $expectedCallId');
        return;
    }
  }

  void reset() {
    BillingConvergenceMetrics.instance.flushToSentry(callId: state.callId);
    _stopBillingRecoveryRetry();
    _connectedStuckSince = null;
    _syncWarningReportedForCurrentCall = false;
    _stuckEndRequested = false;
    _lastOrphanRecoveryEmit = null;
    _recoveryTracking.reset();
    BillingConvergenceMetrics.instance.reset();
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
      socketService.onBillingError = null;
    } catch (_) {}
    super.dispose();
  }

  bool _isTerminalCallState() {
    final lifecycle = state.lifecycleState.toUpperCase();
    return lifecycle == 'SETTLED' || lifecycle == 'ENDING' || lifecycle == 'FAILED';
  }

  bool _isCallStillJoinedOrConnected() {
    final conn = _ref.read(callConnectionControllerProvider);
    if (conn.phase == CallConnectionPhase.connected) {
      return true;
    }
    final call = conn.call;
    if (call == null) return false;
    try {
      // ignore: avoid_dynamic_calls
      final callState = (call as dynamic).state?.value;
      // ignore: avoid_dynamic_calls
      final callingState = callState?.callingState?.toString().toLowerCase();
      if (callingState == null) return false;
      return callingState.contains('joined') || callingState.contains('join');
    } catch (_) {
      return false;
    }
  }

  int? _coerceRemainingSeconds({
    required int? incoming,
    required int? fallback,
    required bool keepLiveRemainingOnZero,
  }) {
    if (incoming == null) return fallback;
    if (!keepLiveRemainingOnZero) return incoming;
    if (incoming > 0) return incoming;
    if (_isCallStillJoinedOrConnected() && fallback != null && fallback > 0) {
      return fallback;
    }
    return incoming;
  }

  CallBillingState _freezeRemainingIfZero(CallBillingState nextState) {
    if (nextState.remainingSeconds == null || nextState.remainingSeconds! > 0) {
      return nextState;
    }
    if (!(_isCallStillJoinedOrConnected() && !_isTerminalCallState())) {
      return nextState;
    }
    final priorRemaining = state.remainingSeconds;
    if (priorRemaining == null || priorRemaining <= 0) {
      return nextState.copyWith(runtimeState: BillingRuntimeState.syncing);
    }
    return nextState.copyWith(
      runtimeState: BillingRuntimeState.syncing,
      remainingSeconds: priorRemaining,
    );
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

final callBillingProvider =
    StateNotifierProvider<CallBillingNotifier, CallBillingState>((ref) {
      return CallBillingNotifier(ref);
    });
