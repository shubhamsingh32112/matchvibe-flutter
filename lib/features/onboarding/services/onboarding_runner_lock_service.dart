import 'package:shared_preferences/shared_preferences.dart';

class OnboardingRunnerLockService {
  static const String _prefix = 'onboarding_runner_lock';

  static String _key(String uid) => '${_prefix}_$uid';

  static Future<bool> tryAcquire({
    required String uid,
    required int ttlMs,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = prefs.getInt(_key(uid)) ?? 0;
    if (existing > 0 && (now - existing) <= ttlMs) {
      return false;
    }

    // Best-effort atomic simulation:
    // 1) write our timestamp
    // 2) read back; only proceed if it matches
    await prefs.setInt(_key(uid), now);
    final readBack = prefs.getInt(_key(uid)) ?? 0;
    return readBack == now;
  }

  static Future<void> release(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(uid));
  }

  static Future<void> clear(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(uid));
  }
}

