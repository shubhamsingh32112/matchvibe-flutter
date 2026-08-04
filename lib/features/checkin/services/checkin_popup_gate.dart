/// Auto-show gate for Daily Check-in.
///
/// Rules (aligned with product plan):
/// - At most once per app process **per IST calendar day** (from server).
/// - Cold start clears memory → can show again the same day if still unclaimed.
/// - After IST midnight, [todayKey] changes → auto-show is allowed again
///   even if the process never restarted.
/// - Deep-link / manual reopen bypass this gate entirely.
class CheckInPopupGate {
  CheckInPopupGate._();

  static String? _autoShownForIstDateKey;

  /// True when we already auto-presented for this IST day in this process.
  static bool hasAutoShownForDate(String istDateKey) =>
      _autoShownForIstDateKey == istDateKey;

  static void markAutoShownForDate(String istDateKey) {
    _autoShownForIstDateKey = istDateKey;
  }

  /// Call on logout so the next account can auto-show.
  static void reset() {
    _autoShownForIstDateKey = null;
  }
}
