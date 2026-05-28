//D:\zztherapy\frontend\lib\features\video\utils\call_overlay_rules.dart
import '../providers/call_billing_provider.dart';
import '../providers/call_billing_selectors.dart';

class CallOverlayPolicy {
  static const Duration maxBillingSyncHintDuration = Duration(seconds: 12);

  /// True when runtime has converged to live billing (not merely stale
  /// `callStartTimeMs` left over after a syncing regression).
  static bool _hasRuntimeConvergence(CallBillingState billing) {
    return billing.runtimeState == BillingRuntimeState.active;
  }

  static bool shouldShowBillingSyncHint({
    required bool isConnected,
    required CallBillingState billing,
    required Duration connectedFor,
  }) {
    if (!isConnected) return false;
    if (_hasRuntimeConvergence(billing)) return false;
    if (!billing.isBillingSyncing) return false;
    return connectedFor <= maxBillingConnectionIssueBeforeEnd;
  }

  static const Duration maxBillingConnectionIssueBeforeEnd = Duration(seconds: 20);

  /// Shown when still connected but server billing never activated after the sync window.
  static bool shouldShowBillingConnectionIssue({
    required bool isConnected,
    required CallBillingState billing,
    required Duration connectedFor,
  }) {
    // Keep UX deterministic: stay in syncing hint while recovery is in-flight.
    // Hard failures are handled by forced end-call path, not a mid-call issue banner.
    return false;
  }

  static bool shouldShowSecurityBlock({
    required bool isScreenCaptured,
  }) {
    // Do not keep a visual full-screen block over live video. We end the call
    // immediately when capture is detected, so rendering a haze layer is
    // avoided to keep UX deterministic.
    return false;
  }
}

/// Returns true when the regular user is in the real final 10 seconds.
bool shouldShowLastTenSecondsHeartbeat({
  required bool isCreator,
  required CallBillingState billing,
}) {
  final remaining = billing.remainingSeconds;
  if (isCreator || !billing.isBillingLive || remaining == null) return false;
  return remaining > 0 && remaining <= 10;
}
