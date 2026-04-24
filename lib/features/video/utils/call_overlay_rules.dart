import '../providers/call_billing_provider.dart';

/// Returns true when the regular user is in the real final 10 seconds.
bool shouldShowLastTenSecondsHeartbeat({
  required bool isCreator,
  required CallBillingState billing,
}) {
  final remaining = billing.remainingSeconds;
  if (isCreator || !billing.isActive || remaining == null) return false;
  return remaining > 0 && remaining <= 10;
}
