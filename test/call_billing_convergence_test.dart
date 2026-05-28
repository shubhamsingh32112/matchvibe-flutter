import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/features/video/providers/call_billing_provider.dart';
import 'package:zztherapy/features/video/providers/call_billing_selectors.dart';

Map<String, dynamic> _recoverEnvelope({
  required int recoveryRequestId,
  required int generatedAtMs,
  required Map<String, dynamic> entry,
  String status = 'ok',
}) {
  return {
    'success': true,
    'status': status,
    'recoveryRequestId': recoveryRequestId,
    'generatedAtMs': generatedAtMs,
    'clientRecoveryRequestId': 'rec_test_$recoveryRequestId',
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
  final ts = serverTimestamp ?? callStartTimeMs + 12_000;
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

void main() {
  group('BillingConvergencePolicy', () {
    test('TEST F — lower sequence update rejected for promotion', () {
      const state = CallBillingState(
        callId: 'call-1',
        billingSequence: 5,
        runtimeState: BillingRuntimeState.syncing,
      );
      final update = {
        'callId': 'call-1',
        'billingSequence': 4,
        'coins': 90,
        'elapsedSeconds': 10,
        'serverTimestamp': 1,
      };
      expect(
        BillingConvergencePolicy.canPromoteFromUpdate(state: state, data: update),
        isFalse,
      );
      expect(
        BillingConvergencePolicy.shouldRejectStaleEventSequence(
          state: state,
          data: update,
        ),
        isTrue,
      );
    });

    test('TEST B — billing:update can promote syncing to active', () {
      const state = CallBillingState(
        callId: 'call-1',
        billingSequence: 3,
        runtimeState: BillingRuntimeState.syncing,
      );
      final update = {
        'callId': 'call-1',
        'billingSequence': 3,
        'coins': 88,
        'elapsedSeconds': 8,
        'serverTimestamp': 1_700_000_010_000,
        'lifecycleState': 'ACTIVE',
      };
      expect(
        BillingConvergencePolicy.canPromoteFromUpdate(state: state, data: update),
        isTrue,
      );
      expect(
        BillingConvergencePolicy.shouldRejectStaleEventSequence(
          state: state,
          data: update,
        ),
        isTrue,
      );
    });

    test('TEST J — zero-sequence update rejected when local sequence exists', () {
      const state = CallBillingState(
        callId: 'call-1',
        billingSequence: 3,
        runtimeState: BillingRuntimeState.active,
      );
      final update = {
        'callId': 'call-1',
        'billingSequence': 0,
        'coins': 50,
        'elapsedSeconds': 5,
        'serverTimestamp': 1,
      };
      expect(
        BillingConvergencePolicy.shouldRejectStaleEventSequence(
          state: state,
          data: update,
        ),
        isTrue,
      );
    });

    test('TEST H — equal seq recover without callStartTime rejected', () {
      const state = CallBillingState(
        callId: 'call-1',
        billingSequence: 2,
        runtimeState: BillingRuntimeState.syncing,
      );
      final entry = {
        'callId': 'call-1',
        'billingSequence': 2,
        'lifecycleState': 'ACTIVE',
      };
      expect(
        BillingConvergencePolicy.canRehydrateEqualSequenceRecover(
          state: state,
          expectedCallId: 'call-1',
          entry: entry,
        ),
        isFalse,
      );
      expect(
        BillingConvergencePolicy.shouldRejectRecoverMergeSequence(
          state: state,
          entry: entry,
          expectedCallId: 'call-1',
          envelope: const {'recoveryRequestId': 1, 'generatedAtMs': 1},
          tracking: BillingRecoveryTracking(),
        ),
        isTrue,
      );
    });

    test('TEST K — ACTIVE equal seq refresh with newer envelope', () {
      const state = CallBillingState(
        callId: 'call-1',
        billingSequence: 4,
        runtimeState: BillingRuntimeState.active,
        userCoins: 50,
        elapsedSeconds: 8,
        lastServerTimestampMs: 1_700_000_000_000,
        lifecycleState: 'ACTIVE',
        callStartTimeMs: 1_700_000_000_000,
      );
      final tracking = BillingRecoveryTracking()
        ..recordApplied({
          'recoveryRequestId': 1,
          'generatedAtMs': 1000,
        });
      final entry = _activeEntry(
        callId: 'call-1',
        billingSequence: 4,
        coins: 88,
        elapsedSeconds: 12,
      );
      expect(
        BillingConvergencePolicy.shouldApplyEqualSequenceRefresh(
          state: state,
          expectedCallId: 'call-1',
          envelope: _recoverEnvelope(
            recoveryRequestId: 2,
            generatedAtMs: 2000,
            entry: entry,
          ),
          entry: entry,
          tracking: tracking,
        ),
        isTrue,
      );
      final result = BillingRecoveryMerge.apply(
        state: state,
        tracking: tracking,
        envelope: _recoverEnvelope(
          recoveryRequestId: 2,
          generatedAtMs: 2000,
          entry: entry,
        ),
        expectedCallId: 'call-1',
      );
      expect(result.outcome, BillingRecoveryApplyOutcome.applied);
      expect(result.state.runtimeState, BillingRuntimeState.active);
      expect(result.state.userCoins, 88);
      expect(result.state.elapsedSeconds, 12);
    });

    test('TEST L — ACTIVE equal seq identical fields rejected', () {
      const state = CallBillingState(
        callId: 'call-1',
        billingSequence: 4,
        runtimeState: BillingRuntimeState.active,
        userCoins: 100,
        elapsedSeconds: 12,
        lastServerTimestampMs: 1_700_000_012_000,
        lifecycleState: 'ACTIVE',
        callStartTimeMs: 1_700_000_000_000,
      );
      final tracking = BillingRecoveryTracking()
        ..recordApplied({
          'recoveryRequestId': 1,
          'generatedAtMs': 1000,
        });
      final entry = _activeEntry(callId: 'call-1', billingSequence: 4);
      final result = BillingRecoveryMerge.apply(
        state: state,
        tracking: tracking,
        envelope: _recoverEnvelope(
          recoveryRequestId: 2,
          generatedAtMs: 2000,
          entry: entry,
        ),
        expectedCallId: 'call-1',
      );
      expect(result.outcome, BillingRecoveryApplyOutcome.rejectedNoMaterialChange);
      expect(result.state.userCoins, 100);
    });

    test('TEST N — ACTIVE equal seq RECOVERING lifecycle rejected', () {
      const state = CallBillingState(
        callId: 'call-1',
        billingSequence: 4,
        runtimeState: BillingRuntimeState.active,
        userCoins: 50,
        lifecycleState: 'ACTIVE',
      );
      final tracking = BillingRecoveryTracking();
      final entry = {
        'callId': 'call-1',
        'billingSequence': 4,
        'lifecycleState': 'RECOVERING',
        'callStartTime': 1_700_000_000_000,
        'coins': 99,
        'elapsedSeconds': 20,
        'serverTimestamp': 1_700_000_020_000,
      };
      expect(
        BillingConvergencePolicy.shouldApplyEqualSequenceRefresh(
          state: state,
          expectedCallId: 'call-1',
          envelope: _recoverEnvelope(
            recoveryRequestId: 1,
            generatedAtMs: 1000,
            entry: entry,
          ),
          entry: entry,
          tracking: tracking,
        ),
        isFalse,
      );
    });
  });

  group('BillingRecoveryMerge', () {
  const callId = 'call-abc';

    test('TEST A — recover_success equal sequence while syncing converges ACTIVE', () {
      var state = const CallBillingState(
        callId: callId,
        billingSequence: 4,
        runtimeState: BillingRuntimeState.syncing,
      );
      final tracking = BillingRecoveryTracking();
      final envelope = _recoverEnvelope(
        recoveryRequestId: 1,
        generatedAtMs: 1000,
        entry: _activeEntry(callId: callId, billingSequence: 4),
      );
      final result = BillingRecoveryMerge.apply(
        state: state,
        tracking: tracking,
        envelope: envelope,
        expectedCallId: callId,
      );
      expect(result.outcome, BillingRecoveryApplyOutcome.applied);
      expect(result.state.runtimeState, BillingRuntimeState.active);
      expect(result.state.callStartTimeMs, isNotNull);
      state = result.state;
    });

    test('TEST C — late bootstrapping after ACTIVE ignored', () {
      const state = CallBillingState(
        callId: callId,
        billingSequence: 2,
        runtimeState: BillingRuntimeState.active,
        callStartTimeMs: 1_700_000_000_000,
      );
      final tracking = BillingRecoveryTracking()
        ..recordApplied({
          'recoveryRequestId': 5,
          'generatedAtMs': 5000,
        });
      final envelope = {
        'success': true,
        'status': 'bootstrapping',
        'recoveryRequestId': 6,
        'generatedAtMs': 6000,
        'activeCalls': [],
      };
      final result = BillingRecoveryMerge.apply(
        state: state,
        tracking: tracking,
        envelope: envelope,
        expectedCallId: callId,
      );
      expect(result.outcome, BillingRecoveryApplyOutcome.rejectedDowngrade);
      expect(result.state.runtimeState, BillingRuntimeState.active);
    });

    test('TEST D — older recovery response rejected', () {
      const state = CallBillingState(
        callId: callId,
        billingSequence: 3,
        runtimeState: BillingRuntimeState.syncing,
      );
      final tracking = BillingRecoveryTracking()
        ..recordApplied({
          'recoveryRequestId': 10,
          'generatedAtMs': 10_000,
        });
      final envelope = _recoverEnvelope(
        recoveryRequestId: 9,
        generatedAtMs: 9_500,
        entry: _activeEntry(callId: callId, billingSequence: 3),
      );
      final result = BillingRecoveryMerge.apply(
        state: state,
        tracking: tracking,
        envelope: envelope,
        expectedCallId: callId,
      );
      expect(result.outcome, BillingRecoveryApplyOutcome.rejectedOlder);
      expect(result.state.runtimeState, BillingRuntimeState.syncing);
    });

    test('TEST E — duplicate recovery response is idempotent', () {
      final tracking = BillingRecoveryTracking()
        ..recordApplied({
          'recoveryRequestId': 7,
          'generatedAtMs': 7000,
        });
      const state = CallBillingState(
        callId: callId,
        billingSequence: 2,
        runtimeState: BillingRuntimeState.active,
        callStartTimeMs: 1_700_000_000_000,
      );
      final envelope = _recoverEnvelope(
        recoveryRequestId: 7,
        generatedAtMs: 7000,
        entry: _activeEntry(callId: callId, billingSequence: 2),
      );
      final result = BillingRecoveryMerge.apply(
        state: state,
        tracking: tracking,
        envelope: envelope,
        expectedCallId: callId,
      );
      expect(result.outcome, BillingRecoveryApplyOutcome.duplicate);
      expect(result.state.runtimeState, BillingRuntimeState.active);
    });

    test('TEST G — different callId recovery rejected', () {
      const state = CallBillingState(
        callId: callId,
        billingSequence: 1,
        runtimeState: BillingRuntimeState.syncing,
      );
      final tracking = BillingRecoveryTracking();
      final envelope = _recoverEnvelope(
        recoveryRequestId: 1,
        generatedAtMs: 100,
        entry: _activeEntry(callId: 'other-call', billingSequence: 2),
      );
      final result = BillingRecoveryMerge.apply(
        state: state,
        tracking: tracking,
        envelope: envelope,
        expectedCallId: callId,
      );
      expect(result.outcome, BillingRecoveryApplyOutcome.rejectedNotSuccess);
    });

    test('TEST I — reconnect storm: newest wins, final ACTIVE', () {
      var state = const CallBillingState(
        callId: callId,
        billingSequence: 2,
        runtimeState: BillingRuntimeState.syncing,
      );
      var tracking = BillingRecoveryTracking();

      final stale = BillingRecoveryMerge.apply(
        state: state,
        tracking: tracking,
        envelope: _recoverEnvelope(
          recoveryRequestId: 1,
          generatedAtMs: 100,
          entry: _activeEntry(callId: callId, billingSequence: 2, callStartTimeMs: 100),
        ),
        expectedCallId: callId,
      );
      expect(stale.outcome, BillingRecoveryApplyOutcome.applied);
      state = stale.state;
      tracking = stale.tracking;

      final newer = BillingRecoveryMerge.apply(
        state: state,
        tracking: tracking,
        envelope: _recoverEnvelope(
          recoveryRequestId: 3,
          generatedAtMs: 300,
          entry: _activeEntry(
            callId: callId,
            billingSequence: 5,
            callStartTimeMs: 200,
          ),
        ),
        expectedCallId: callId,
      );
      expect(newer.outcome, BillingRecoveryApplyOutcome.applied);
      expect(newer.state.runtimeState, BillingRuntimeState.active);
      expect(newer.state.billingSequence, 5);

      final olderAfterNew = BillingRecoveryMerge.apply(
        state: newer.state,
        tracking: newer.tracking,
        envelope: _recoverEnvelope(
          recoveryRequestId: 2,
          generatedAtMs: 200,
          entry: _activeEntry(callId: callId, billingSequence: 2),
        ),
        expectedCallId: callId,
      );
      expect(olderAfterNew.outcome, BillingRecoveryApplyOutcome.rejectedOlder);
      expect(olderAfterNew.state.runtimeState, BillingRuntimeState.active);
      expect(olderAfterNew.state.billingSequence, 5);
    });

    test('TEST O — replay same envelope key is duplicate', () {
      var state = const CallBillingState(
        callId: callId,
        billingSequence: 3,
        runtimeState: BillingRuntimeState.syncing,
      );
      var tracking = BillingRecoveryTracking();
      final envelope = _recoverEnvelope(
        recoveryRequestId: 5,
        generatedAtMs: 5000,
        entry: _activeEntry(callId: callId, billingSequence: 3),
      );
      final first = BillingRecoveryMerge.apply(
        state: state,
        tracking: tracking,
        envelope: envelope,
        expectedCallId: callId,
      );
      expect(first.outcome, BillingRecoveryApplyOutcome.applied);
      state = first.state;
      tracking = first.tracking;

      final replay = BillingRecoveryMerge.apply(
        state: state,
        tracking: tracking,
        envelope: envelope,
        expectedCallId: callId,
      );
      expect(replay.outcome, BillingRecoveryApplyOutcome.duplicate);
      expect(replay.state.userCoins, state.userCoins);
      expect(replay.state.billingSequence, state.billingSequence);
    });
  });

  group('Billing terminal + controller convergence', () {
    const callId = 'call-terminal';

    test('TEST B2 — terminal state rejects late billing:update resurrection', () {
      const state = CallBillingState(
        callId: callId,
        billingSequence: 10,
        runtimeState: BillingRuntimeState.settled,
      );
      expect(
        shouldRejectEventAfterTerminal(
          state: state,
          eventCallId: callId,
        ),
        isTrue,
      );
    });

    test('TEST P — settled rejects recover merge at policy level', () {
      const state = CallBillingState(
        callId: callId,
        billingSequence: 5,
        runtimeState: BillingRuntimeState.settled,
      );
      expect(
        shouldRejectEventAfterTerminal(state: state, eventCallId: callId),
        isTrue,
      );
    });

    test('TEST Q — ending rejects billing update resurrection', () {
      const state = CallBillingState(
        callId: callId,
        billingSequence: 5,
        runtimeState: BillingRuntimeState.ending,
      );
      expect(
        shouldRejectEventAfterTerminal(state: state, eventCallId: callId),
        isTrue,
      );
      expect(isTerminalBillingState(BillingRuntimeState.ending), isTrue);
    });

    test('TEST R — callStartTimeMs alone is not reconnect evidence', () {
      const state = CallBillingState(
        callId: callId,
        billingSequence: 0,
        runtimeState: BillingRuntimeState.init,
        callStartTimeMs: 1_700_000_000_000,
      );
      expect(hadPriorBillingEvidenceForReconnect(state), isFalse);
    });

    test('TEST A2 — stale anchor does not suppress billing start retry', () {
      const billing = CallBillingState(
        callId: callId,
        billingSequence: 4,
        runtimeState: BillingRuntimeState.syncing,
        callStartTimeMs: 1_700_000_000_000,
      );
      expect(billing.isBillingLive, isFalse);
      expect(shouldSuppressBillingStartRetry(isBillingLive: billing.isBillingLive), isFalse);
    });

    test('TEST A3 — ACTIVE suppresses billing start retry only', () {
      const billing = CallBillingState(
        callId: callId,
        billingSequence: 4,
        runtimeState: BillingRuntimeState.active,
        callStartTimeMs: 1_700_000_000_000,
      );
      expect(shouldSuppressBillingStartRetry(isBillingLive: billing.isBillingLive), isTrue);
    });

    test('TEST A4 — foreground resume skips recover only when ACTIVE', () {
      expect(
        shouldSkipForegroundBillingRecoverOnResume(BillingRuntimeState.active),
        isTrue,
      );
      expect(
        shouldSkipForegroundBillingRecoverOnResume(BillingRuntimeState.recovering),
        isFalse,
      );
      expect(
        shouldSkipForegroundBillingRecoverOnResume(BillingRuntimeState.syncing),
        isFalse,
      );
      expect(shouldForceForegroundBillingRecover(BillingRuntimeState.recovering), isTrue);
      expect(shouldForceForegroundBillingRecover(BillingRuntimeState.active), isFalse);
    });

    test('TEST D2 — late bootstrapping after SETTLED ignored via terminal guard', () {
      const state = CallBillingState(
        callId: callId,
        billingSequence: 2,
        runtimeState: BillingRuntimeState.settled,
      );
      expect(
        shouldRejectEventAfterTerminal(
          state: state,
          eventCallId: callId,
        ),
        isTrue,
      );
      expect(isTerminalBillingState(BillingRuntimeState.settled), isTrue);
    });
  });
}
