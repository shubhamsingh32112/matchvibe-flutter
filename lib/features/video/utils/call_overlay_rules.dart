import '../providers/call_billing_provider.dart';

class CallOverlayPolicy {
  static const Duration maxBillingSyncHintDuration = Duration(seconds: 8);

  static bool shouldShowBillingSyncHint({
    required bool isConnected,
    required CallBillingState billing,
    required Duration connectedFor,
  }) {
    if (!isConnected) return false;
    if (billing.isActive || billing.callStartTimeMs != null) return false;
    return connectedFor <= maxBillingSyncHintDuration;
  }

  /// Shown when still connected but server billing never activated after the sync window.
  static bool shouldShowBillingConnectionIssue({
    required bool isConnected,
    required CallBillingState billing,
    required Duration connectedFor,
  }) {
    if (!isConnected) return false;
    if (billing.isActive || billing.callStartTimeMs != null) return false;
    return connectedFor > maxBillingSyncHintDuration;
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
  if (isCreator || !billing.isActive || remaining == null) return false;
  return remaining > 0 && remaining <= 10;
}
