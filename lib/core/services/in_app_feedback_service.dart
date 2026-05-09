import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Best-effort in-app haptics/vibration with dedupe + rate limiting.
///
/// This is intentionally lightweight (no new plugin dependency).
class InAppFeedbackService {
  InAppFeedbackService._({
    int Function()? nowMs,
    Future<void> Function()? haptic,
    bool Function()? isMobile,
  })  : _nowMs = nowMs ?? _defaultNowMs,
        _haptic = haptic ?? _defaultHaptic,
        _isMobileFn = isMobile ?? _defaultIsMobile;

  static final InAppFeedbackService instance = InAppFeedbackService._();

  @visibleForTesting
  static InAppFeedbackService test({
    required int Function() nowMs,
    required Future<void> Function() haptic,
    bool Function()? isMobile,
  }) {
    return InAppFeedbackService._(nowMs: nowMs, haptic: haptic, isMobile: isMobile);
  }

  // Cooldown to avoid vibration spam during bursts.
  static const Duration _cooldown = Duration(milliseconds: 1200);

  // Dedupe window for the same event id arriving via WS + FCM.
  static const Duration _dedupeWindow = Duration(seconds: 10);

  final int Function() _nowMs;
  final Future<void> Function() _haptic;
  final bool Function() _isMobileFn;

  static int _defaultNowMs() => DateTime.now().millisecondsSinceEpoch;
  static Future<void> _defaultHaptic() {
    // `lightImpact()` is frequently imperceptible or a no-op on many Android devices
    // (and on emulators). Prefer a stronger, more widely supported signal there.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return HapticFeedback.vibrate();
    }
    return HapticFeedback.lightImpact();
  }
  static bool _defaultIsMobile() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  int _lastFeedbackAtMs = 0;
  final LinkedHashMap<String, int> _recentKeysMs = LinkedHashMap<String, int>();

  void notifyChatMessage({required String dedupeKey}) {
    if (!_isMobileFn()) return;

    final nowMs = _nowMs();

    // Prune old dedupe keys (LinkedHashMap maintains insertion order).
    final cutoff = nowMs - _dedupeWindow.inMilliseconds;
    while (_recentKeysMs.isNotEmpty) {
      final firstKey = _recentKeysMs.keys.first;
      final firstTs = _recentKeysMs[firstKey] ?? 0;
      if (firstTs >= cutoff) break;
      _recentKeysMs.remove(firstKey);
    }

    final lastSeen = _recentKeysMs[dedupeKey];
    if (lastSeen != null && (nowMs - lastSeen) <= _dedupeWindow.inMilliseconds) {
      return;
    }

    if (_lastFeedbackAtMs > 0 &&
        (nowMs - _lastFeedbackAtMs) <= _cooldown.inMilliseconds) {
      return;
    }

    _recentKeysMs[dedupeKey] = nowMs;
    _lastFeedbackAtMs = nowMs;

    // Best-effort: haptics can fail on some devices or be disabled by OS settings.
    _haptic().catchError((_) {});
  }
}

