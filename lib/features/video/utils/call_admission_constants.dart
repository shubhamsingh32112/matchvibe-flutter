/// Must match backend MIN_COINS_TO_CALL default when app-config is unavailable.
const int kMinCoinsToCall = 450;

/// Whether a consumer may pass the **client** call-admission coin gate.
///
/// Matches website / backend policy:
/// - Welcome free-call eligible users skip the wallet minimum (intro credits are
///   **seconds**, not coins — never add them into the wallet total).
/// - Otherwise the face-value wallet must be ≥ [minCoinsToCall].
bool meetsCallCoinAdmission({
  required int walletCoins,
  required bool welcomeFreeCallEligible,
  bool freeCallEnabled = true,
  int minCoinsToCall = kMinCoinsToCall,
}) {
  if (freeCallEnabled && welcomeFreeCallEligible) return true;
  final min = minCoinsToCall > 0 ? minCoinsToCall : kMinCoinsToCall;
  return walletCoins >= min;
}
