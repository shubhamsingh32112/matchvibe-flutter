import 'call_billing_provider.dart';

extension CallBillingStateSelectors on CallBillingState {
  bool get isBillingLive =>
      runtimeState == BillingRuntimeState.active ||
      runtimeState == BillingRuntimeState.recovering;

  bool get isBillingSyncing => runtimeState == BillingRuntimeState.syncing;

  bool get isBillingSettled => runtimeState == BillingRuntimeState.settled;

  bool get isBillingEnding => runtimeState == BillingRuntimeState.ending;

  bool get isBillingTerminal =>
      runtimeState == BillingRuntimeState.settled ||
      runtimeState == BillingRuntimeState.failed;
}

bool shouldShowLiveUserCoins({
  required bool isCreator,
  required CallBillingState billing,
}) {
  return !isCreator && billing.isBillingLive;
}

