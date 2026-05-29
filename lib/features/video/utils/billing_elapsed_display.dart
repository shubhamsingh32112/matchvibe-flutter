import '../providers/call_billing_provider.dart';
import '../providers/call_billing_selectors.dart';

/// Shared elapsed-second estimate for overlay timer and duration-limit watchdog.
///
/// Uses server `elapsedSeconds` as the source of truth, with light drift
/// smoothing from `callStartTimeMs`/`serverTimestamp` for UI continuity.
int? estimateBillingElapsedSeconds(
  CallBillingState billing, {
  int? nowMs,
}) {
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  final limit = billing.durationLimit;

  var display = billing.elapsedSeconds;
  if (billing.isBillingLive && billing.callStartTimeMs != null) {
    final wallClockElapsed =
        ((now - billing.callStartTimeMs!) / 1000).floor();
    if (wallClockElapsed > display) {
      display = wallClockElapsed;
    }
  } else if (billing.lastServerTimestampMs != null) {
    final driftSeconds =
        ((now - billing.lastServerTimestampMs!) / 1000).floor();
    if (driftSeconds > 0) {
      display += driftSeconds;
    }
  }

  if (display <= 0 && billing.elapsedSeconds <= 0) {
    return null;
  }
  if (display < 0) {
    display = 0;
  }
  if (limit != null && limit > 0 && display > limit) {
    display = limit;
  }
  return display;
}

/// Seconds until duration limit is reached (for one-shot watchdog timer).
int? estimateSecondsUntilDurationLimit(CallBillingState billing, {int? nowMs}) {
  final limit = billing.durationLimit;
  if (limit == null || limit <= 0) return null;
  final elapsed = estimateBillingElapsedSeconds(billing, nowMs: nowMs);
  if (elapsed == null) return null;
  return (limit - elapsed).clamp(0, limit);
}
