import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/features/video/providers/call_billing_provider.dart';
import 'package:zztherapy/features/video/utils/billing_elapsed_display.dart';

void main() {
  test('does not derive elapsed from remainingSeconds', () {
    const billing = CallBillingState(
      runtimeState: BillingRuntimeState.active,
      durationLimit: 300,
      remainingSeconds: 100,
      elapsedSeconds: 50,
    );
    expect(estimateBillingElapsedSeconds(billing), 50);
    expect(estimateSecondsUntilDurationLimit(billing), 250);
  });

  test('drifts from serverTimestamp when no remaining', () {
    const now = 1_700_000_010_000;
    const billing = CallBillingState(
      runtimeState: BillingRuntimeState.active,
      elapsedSeconds: 10,
      lastServerTimestampMs: 1_700_000_000_000,
    );
    expect(estimateBillingElapsedSeconds(billing, nowMs: now), 20);
  });

  test('uses callStartTime smoothing while billing is live', () {
    const start = 1_700_000_000_000;
    const now = start + 30 * 1000;
    const billing = CallBillingState(
      runtimeState: BillingRuntimeState.active,
      durationLimit: 60,
      remainingSeconds: 30,
      callStartTimeMs: start,
      elapsedSeconds: 5,
    );
    expect(estimateBillingElapsedSeconds(billing, nowMs: now), 30);
    expect(estimateSecondsUntilDurationLimit(billing, nowMs: now), 30);
  });

  test('caps elapsed to durationLimit for watchdog safety', () {
    const start = 1_700_000_000_000;
    const now = start + 120 * 1000;
    const billing = CallBillingState(
      runtimeState: BillingRuntimeState.active,
      durationLimit: 60,
      callStartTimeMs: start,
      elapsedSeconds: 10,
    );
    expect(estimateBillingElapsedSeconds(billing, nowMs: now), 60);
    expect(estimateSecondsUntilDurationLimit(billing, nowMs: now), 0);
  });
}
