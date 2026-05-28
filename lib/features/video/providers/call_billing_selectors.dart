import 'call_billing_provider.dart';

extension CallBillingStateSelectors on CallBillingState {
  bool get isBillingLive =>
      runtimeState == BillingRuntimeState.active ||
      runtimeState == BillingRuntimeState.recovering;

  bool get isBillingSyncing =>
      runtimeState == BillingRuntimeState.syncing ||
      runtimeState == BillingRuntimeState.recovering;

  bool get isBillingSettled => runtimeState == BillingRuntimeState.settled;

  bool get isBillingEnding => runtimeState == BillingRuntimeState.ending;

  bool get isBillingTerminal => isTerminalBillingState(runtimeState);
}

/// Controller retry must depend on runtime authority only — not stale anchors.
bool shouldSuppressBillingStartRetry({required bool isBillingLive}) {
  return isBillingLive;
}

/// Foreground resume: skip explicit recover only when billing is converged (ACTIVE).
///
/// Do not use [CallBillingState.isBillingLive] here — `recovering` is unstable and
/// must still run `ensureConnected` + `billing:recover-state`.
bool shouldSkipForegroundBillingRecoverOnResume(BillingRuntimeState runtime) {
  return runtime == BillingRuntimeState.active;
}

/// True when app resume should always emit explicit billing recovery.
bool shouldForceForegroundBillingRecover(BillingRuntimeState runtime) {
  return runtime == BillingRuntimeState.recovering;
}

bool shouldShowLiveUserCoins({
  required bool isCreator,
  required CallBillingState billing,
}) {
  return !isCreator && billing.isBillingLive;
}

