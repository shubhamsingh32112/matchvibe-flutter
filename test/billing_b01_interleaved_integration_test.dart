import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/features/video/providers/call_billing_provider.dart';
import 'package:zztherapy/features/video/providers/call_billing_selectors.dart';

int? _readIntMsTest(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

/// Timestamped step log for B-01 integration evidence (exported to docs).
class B01ScenarioLogEntry {
  B01ScenarioLogEntry({
    required this.stepIndex,
    required this.atUtc,
    required this.phase,
    required this.runtimeState,
    required this.billingSequence,
    required this.userCoins,
    required this.elapsedSeconds,
    this.detail,
    this.outcome,
  });

  final int stepIndex;
  final DateTime atUtc;
  final String phase;
  final String runtimeState;
  final int billingSequence;
  final int userCoins;
  final int elapsedSeconds;
  final String? outcome;
  final Map<String, Object?>? detail;

  Map<String, Object?> toJson() => {
        'step': stepIndex,
        'at_utc': atUtc.toIso8601String(),
        'phase': phase,
        'runtime_state': runtimeState,
        'billing_sequence': billingSequence,
        'user_coins': userCoins,
        'elapsed_seconds': elapsedSeconds,
        if (outcome != null) 'outcome': outcome,
        if (detail != null) 'detail': detail,
      };

  @override
  String toString() =>
      '[${atUtc.toIso8601String()}] #$stepIndex $phase → $runtimeState seq=$billingSequence coins=$userCoins elapsed=${elapsedSeconds}s${outcome != null ? ' ($outcome)' : ''}';
}

/// Mirrors [CallBillingNotifier] socket handlers for deterministic interleaving tests.
class BillingConvergenceEventSimulator {
  BillingConvergenceEventSimulator({
    required CallBillingState initial,
    BillingRecoveryTracking? tracking,
  })  : state = initial,
        tracking = tracking ?? BillingRecoveryTracking();

  CallBillingState state;
  BillingRecoveryTracking tracking;
  final List<B01ScenarioLogEntry> log = [];
  int _step = 0;

  void _record(
    String phase, {
    String? outcome,
    Map<String, Object?>? detail,
  }) {
    _step += 1;
    log.add(
      B01ScenarioLogEntry(
        stepIndex: _step,
        atUtc: DateTime.now().toUtc(),
        phase: phase,
        runtimeState: state.runtimeState.name,
        billingSequence: state.billingSequence,
        userCoins: state.userCoins,
        elapsedSeconds: state.elapsedSeconds,
        outcome: outcome,
        detail: detail,
      ),
    );
  }

  /// Same semantics as [CallBillingNotifier._enterReconnectConvergenceWait].
  void simulateSocketDisconnect() {
    final hadPrior = hadPriorBillingEvidenceForReconnect(state);
    final priorRuntime = state.runtimeState;
    if (hadPrior) {
      if (state.runtimeState != BillingRuntimeState.recovering) {
        state = state.copyWith(
          runtimeState: BillingRuntimeState.recovering,
          clearCallStartTimeMs: true,
        );
      }
    } else if (state.runtimeState == BillingRuntimeState.init) {
      state = state.copyWith(runtimeState: BillingRuntimeState.syncing);
    } else if (state.runtimeState != BillingRuntimeState.syncing &&
        state.runtimeState != BillingRuntimeState.recovering) {
      state = state.copyWith(runtimeState: BillingRuntimeState.syncing);
    }
    _record(
      'socket_disconnect',
      outcome: 'regressed_${priorRuntime.name}_to_${state.runtimeState.name}',
      detail: {
        'had_prior_billing_evidence': hadPrior,
        'is_billing_live_after': state.isBillingLive,
      },
    );
  }

  /// Same semantics as [CallBillingNotifier] `onBillingUpdate` handler.
  bool applyBillingUpdate(Map<String, dynamic> data) {
    if (shouldRejectEventAfterTerminal(
      state: state,
      eventCallId: data['callId'] as String?,
    )) {
      _record('billing_update', outcome: 'rejected_terminal');
      return false;
    }

    final promote = BillingConvergencePolicy.canPromoteFromUpdate(
      state: state,
      data: data,
    );
    final stale = BillingConvergencePolicy.shouldRejectStaleEventSequence(
      state: state,
      data: data,
    );
    if (!promote && stale) {
      _record(
        'billing_update',
        outcome: 'dropped_stale_sequence',
        detail: {
          'incoming_sequence': data['billingSequence'],
          'promote': promote,
        },
      );
      return false;
    }
    if (!promote &&
        (state.runtimeState == BillingRuntimeState.init ||
            state.runtimeState == BillingRuntimeState.syncing)) {
      _record('billing_update', outcome: 'ignored_non_promote_syncing');
      return false;
    }

    final eventCallId = data['callId'] as String?;
    if (eventCallId == null || eventCallId != state.callId) {
      _record('billing_update', outcome: 'rejected_call_id_mismatch');
      return false;
    }

    final coins = (data['coins'] as num?)?.toInt();
    final earnings = (data['earnings'] as num?)?.toDouble();
    final elapsed = (data['elapsedSeconds'] as num?)?.toInt();
    final remaining = (data['remainingSeconds'] as num?)?.toInt();
    final durationLimit = (data['durationLimit'] as num?)?.toInt();
    final serverTs = _readIntMsTest(data['serverTimestamp']);
    final startMs = _readIntMsTest(data['callStartTime']);
    final lifecycleState =
        data['lifecycleState']?.toString() ?? state.lifecycleState;
    final seq = (data['billingSequence'] as num?)?.toInt() ?? 0;

    state = state.copyWith(
      runtimeState: BillingRuntimeState.active,
      billingSequence: seq > 0 ? seq : state.billingSequence,
      lifecycleState: lifecycleState,
      userCoins: coins ?? state.userCoins,
      creatorEarnings: earnings ?? state.creatorEarnings,
      elapsedSeconds: elapsed ?? state.elapsedSeconds,
      remainingSeconds: remaining ?? state.remainingSeconds,
      durationLimit: durationLimit ?? state.durationLimit,
      lastServerTimestampMs: serverTs ?? state.lastServerTimestampMs,
      callStartTimeMs: startMs ?? state.callStartTimeMs,
    );
    _record(
      'billing_update',
      outcome: promote ? 'applied_with_promotion' : 'applied',
      detail: {
        'incoming_sequence': seq,
        'promote': promote,
      },
    );
    return true;
  }

  /// Same merge path as [CallBillingNotifier.mergeRecoverPayload] (success path).
  BillingRecoveryApplyOutcome applyRecoverEnvelope(
    Map<String, dynamic> envelope, {
    required String expectedCallId,
  }) {
    if (shouldRejectEventAfterTerminal(
      state: state,
      eventCallId: expectedCallId,
    )) {
      _record('recover_envelope', outcome: 'rejected_terminal');
      return BillingRecoveryApplyOutcome.rejectedNotSuccess;
    }

    final priorRuntime = state.runtimeState.name;
    final mergeResult = BillingRecoveryMerge.apply(
      state: state,
      tracking: tracking,
      envelope: envelope,
      expectedCallId: expectedCallId,
    );
    tracking = mergeResult.tracking;

    if (mergeResult.outcome == BillingRecoveryApplyOutcome.applied) {
      state = mergeResult.state;
      final seq = mergeResult.state.billingSequence;
      final refreshKind = seq > 0 && seq == state.billingSequence
          ? (priorRuntime == BillingRuntimeState.active.name
              ? 'equal_sequence_active_refresh'
              : 'equal_sequence_rehydrate_allowed')
          : 'recover_applied_higher_seq';
      _record(
        'recover_envelope',
        outcome: mergeResult.outcome.name,
        detail: {
          'recovery_request_id': envelope['recoveryRequestId'],
          'convergence_metric': refreshKind,
          'prior_runtime': priorRuntime,
        },
      );
    } else {
      _record(
        'recover_envelope',
        outcome: mergeResult.outcome.name,
        detail: {
          'recovery_request_id': envelope['recoveryRequestId'],
          'prior_runtime': priorRuntime,
        },
      );
    }
    return mergeResult.outcome;
  }

  void simulateSocketReconnect() {
    _record('socket_reconnect', outcome: 'recovery_requested');
  }

  /// Same semantics as `onBillingSettled`.
  bool applyBillingSettled(Map<String, dynamic> data) {
    final stale = BillingConvergencePolicy.shouldRejectStaleEventSequence(
      state: state,
      data: data,
    );
    if (stale) {
      _record('billing_settled', outcome: 'dropped_stale_sequence');
      return false;
    }
    final eventCallId = data['callId'] as String?;
    if (eventCallId == null || eventCallId != state.callId) {
      _record('billing_settled', outcome: 'rejected_call_id_mismatch');
      return false;
    }
    final totalDeducted = (data['totalDeducted'] as num?)?.toInt() ?? 0;
    final seq = (data['billingSequence'] as num?)?.toInt() ?? 0;
    state = state.copyWith(
      runtimeState: BillingRuntimeState.settled,
      billingSequence: seq > 0 ? seq : state.billingSequence,
      lifecycleState: 'SETTLED',
      finalCoins: (data['finalCoins'] as num?)?.toInt(),
      totalDeducted: totalDeducted,
      totalEarned: (data['totalEarned'] as num?)?.toInt(),
      durationSeconds: (data['durationSeconds'] as num?)?.toInt(),
    );
    _record(
      'billing_settled',
      outcome: 'applied',
      detail: {
        'total_deducted': totalDeducted,
        'incoming_sequence': seq,
      },
    );
    return true;
  }
}

Map<String, dynamic> _recoverEnvelope({
  required int recoveryRequestId,
  required int generatedAtMs,
  required Map<String, dynamic> entry,
}) {
  return {
    'success': true,
    'status': 'ok',
    'recoveryRequestId': recoveryRequestId,
    'generatedAtMs': generatedAtMs,
    'clientRecoveryRequestId': 'rec_b01_$recoveryRequestId',
    'activeCalls': [entry],
  };
}

Map<String, dynamic> _activeEntry({
  required String callId,
  required int billingSequence,
  int callStartTimeMs = 1_700_000_000_000,
  int coins = 100,
  int elapsedSeconds = 12,
  int? serverTimestamp,
}) {
  final ts = serverTimestamp ?? callStartTimeMs + (elapsedSeconds * 1000);
  return {
    'callId': callId,
    'billingSequence': billingSequence,
    'lifecycleState': 'ACTIVE',
    'callStartTime': callStartTimeMs,
    'coins': coins,
    'elapsedSeconds': elapsedSeconds,
    'serverTimestamp': ts,
  };
}

Map<String, dynamic> _billingUpdate({
  required String callId,
  required int billingSequence,
  required int coins,
  required int elapsedSeconds,
  int callStartTimeMs = 1_700_000_000_000,
  int? serverTimestamp,
}) {
  return {
    'callId': callId,
    'billingSequence': billingSequence,
    'lifecycleState': 'ACTIVE',
    'coins': coins,
    'elapsedSeconds': elapsedSeconds,
    'callStartTime': callStartTimeMs,
    'serverTimestamp':
        serverTimestamp ?? callStartTimeMs + (elapsedSeconds * 1000),
  };
}

void main() {
  const callId = 'call-b01-interleave';
  const seq = 7;
  const anchorStart = 1_700_000_000_000;

  group('B-01 — ACTIVE disconnect / equal-seq recover / delayed update / reconnect / settle', () {
    late BillingConvergenceEventSimulator sim;
    late DateTime runStartedUtc;

    setUp(() {
      runStartedUtc = DateTime.now().toUtc();
      sim = BillingConvergenceEventSimulator(
        initial: CallBillingState(
          callId: callId,
          billingSequence: seq,
          runtimeState: BillingRuntimeState.active,
          lifecycleState: 'ACTIVE',
          userCoins: 80,
          elapsedSeconds: 10,
          callStartTimeMs: anchorStart,
          lastServerTimestampMs: anchorStart + 10_000,
        ),
      );
      sim.log.add(
        B01ScenarioLogEntry(
          stepIndex: 0,
          atUtc: runStartedUtc,
          phase: 'precondition_active_mid_call',
          runtimeState: BillingRuntimeState.active.name,
          billingSequence: seq,
          userCoins: 80,
          elapsedSeconds: 10,
          outcome: 'stale_local_fields',
          detail: const {
            'note': 'Server will send coins=95/96/97 across interleaved events',
          },
        ),
      );
    });

    test(
      'TEST B-01 — full interleaved sequence converges ACTIVE then SETTLED without regression',
      () {
        // 1) Socket disconnect while mid-call ACTIVE
        sim.simulateSocketDisconnect();
        expect(sim.state.runtimeState, BillingRuntimeState.recovering);
        expect(sim.state.isBillingLive, isTrue);
        expect(sim.state.callStartTimeMs, isNull);

        // 2) Equal-sequence recover while recovering (authoritative refresh)
        final recover1 = sim.applyRecoverEnvelope(
          _recoverEnvelope(
            recoveryRequestId: 101,
            generatedAtMs: 1_700_000_100_000,
            entry: _activeEntry(
              callId: callId,
              billingSequence: seq,
              coins: 95,
              elapsedSeconds: 18,
              callStartTimeMs: anchorStart,
            ),
          ),
          expectedCallId: callId,
        );
        expect(recover1, BillingRecoveryApplyOutcome.applied);
        expect(sim.state.runtimeState, BillingRuntimeState.active);
        expect(sim.state.userCoins, 95);
        expect(sim.state.elapsedSeconds, 18);
        expect(sim.state.billingSequence, seq);

        // 3) Delayed equal-seq billing:update (+2s) — must NOT overwrite recover
        final updateApplied = sim.applyBillingUpdate(
          _billingUpdate(
            callId: callId,
            billingSequence: seq,
            coins: 96,
            elapsedSeconds: 19,
            callStartTimeMs: anchorStart,
          ),
        );
        expect(updateApplied, isFalse);
        expect(sim.state.userCoins, 95);
        expect(sim.state.elapsedSeconds, 18);
        expect(sim.state.runtimeState, BillingRuntimeState.active);

        // 4) Socket reconnect → second equal-seq recover (ACTIVE field refresh)
        sim.simulateSocketReconnect();
        final recover2 = sim.applyRecoverEnvelope(
          _recoverEnvelope(
            recoveryRequestId: 102,
            generatedAtMs: 1_700_000_102_000,
            entry: _activeEntry(
              callId: callId,
              billingSequence: seq,
              coins: 97,
              elapsedSeconds: 20,
              callStartTimeMs: anchorStart,
            ),
          ),
          expectedCallId: callId,
        );
        expect(recover2, BillingRecoveryApplyOutcome.applied);
        expect(sim.state.userCoins, 97);
        expect(sim.state.elapsedSeconds, 20);
        expect(sim.state.runtimeState, BillingRuntimeState.active);

        // 5) Settlement (higher sequence)
        final settled = sim.applyBillingSettled({
          'callId': callId,
          'billingSequence': seq + 1,
          'totalDeducted': 12,
          'finalCoins': 85,
          'durationSeconds': 20,
        });
        expect(settled, isTrue);
        expect(sim.state.runtimeState, BillingRuntimeState.settled);
        expect(sim.state.lifecycleState, 'SETTLED');
        expect(sim.state.totalDeducted, 12);

        // 6) Post-settlement equal-seq update must be rejected
        final postSettleUpdate = sim.applyBillingUpdate(
          _billingUpdate(
            callId: callId,
            billingSequence: seq,
            coins: 50,
            elapsedSeconds: 5,
          ),
        );
        expect(postSettleUpdate, isFalse);
        expect(sim.state.runtimeState, BillingRuntimeState.settled);

        // 7) Post-settlement recover must not resurrect
        final postSettleRecover = sim.applyRecoverEnvelope(
          _recoverEnvelope(
            recoveryRequestId: 103,
            generatedAtMs: 1_700_000_103_000,
            entry: _activeEntry(
              callId: callId,
              billingSequence: seq,
              coins: 99,
              elapsedSeconds: 25,
            ),
          ),
          expectedCallId: callId,
        );
        expect(postSettleRecover, BillingRecoveryApplyOutcome.rejectedNotSuccess);
        expect(sim.state.runtimeState, BillingRuntimeState.settled);

        // Export-friendly trace for docs generation
        // ignore: avoid_print
        print('\n=== B-01 SCENARIO LOG (UTC) ===');
        for (final entry in sim.log) {
          // ignore: avoid_print
          print(entry);
        }
        // ignore: avoid_print
        print('=== END B-01 LOG ===\n');
      },
    );

    test(
      'TEST B-01b — ACTIVE held (no disconnect): equal-seq recover refresh then delayed update dropped',
      () {
        final held = BillingConvergenceEventSimulator(
          initial: CallBillingState(
            callId: callId,
            billingSequence: seq,
            runtimeState: BillingRuntimeState.active,
            lifecycleState: 'ACTIVE',
            userCoins: 80,
            elapsedSeconds: 10,
            callStartTimeMs: anchorStart,
            lastServerTimestampMs: anchorStart + 10_000,
          ),
        );

        final r1 = held.applyRecoverEnvelope(
          _recoverEnvelope(
            recoveryRequestId: 201,
            generatedAtMs: 1_700_000_200_000,
            entry: _activeEntry(
              callId: callId,
              billingSequence: seq,
              coins: 94,
              elapsedSeconds: 17,
            ),
          ),
          expectedCallId: callId,
        );
        expect(r1, BillingRecoveryApplyOutcome.applied);
        expect(held.state.userCoins, 94);

        final dropped = held.applyBillingUpdate(
          _billingUpdate(
            callId: callId,
            billingSequence: seq,
            coins: 96,
            elapsedSeconds: 19,
          ),
        );
        expect(dropped, isFalse);
        expect(held.state.userCoins, 94);

        held.simulateSocketReconnect();
        final r2 = held.applyRecoverEnvelope(
          _recoverEnvelope(
            recoveryRequestId: 202,
            generatedAtMs: 1_700_000_202_000,
            entry: _activeEntry(
              callId: callId,
              billingSequence: seq,
              coins: 97,
              elapsedSeconds: 20,
            ),
          ),
          expectedCallId: callId,
        );
        expect(r2, BillingRecoveryApplyOutcome.applied);

        expect(
          held.applyBillingSettled({
            'callId': callId,
            'billingSequence': seq + 1,
            'totalDeducted': 10,
          }),
          isTrue,
        );
        expect(held.state.runtimeState, BillingRuntimeState.settled);
      },
    );
  });
}
