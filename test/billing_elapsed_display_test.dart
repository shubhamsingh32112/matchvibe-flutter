import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/features/video/providers/call_billing_provider.dart';
import 'package:zztherapy/features/video/utils/billing_elapsed_display.dart';

void main() {
  test('uses remainingSeconds when durationLimit set', () {
    const billing = CallBillingState(
      runtimeState: BillingRuntimeState.active,
      durationLimit: 300,
      remainingSeconds: 100,
      elapsedSeconds: 50,
    );
    expect(estimateBillingElapsedSeconds(billing), 200);
    expect(estimateSecondsUntilDurationLimit(billing), 100);
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

  test('overlay and watchdog share remaining-first path', () {
    const billing = CallBillingState(
      runtimeState: BillingRuntimeState.active,
      durationLimit: 60,
      remainingSeconds: 30,
      callStartTimeMs: 1_700_000_000_000,
      elapsedSeconds: 5,
    );
    expect(estimateBillingElapsedSeconds(billing), 30);
  });
}
