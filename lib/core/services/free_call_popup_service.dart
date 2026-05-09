import 'package:shared_preferences/shared_preferences.dart';

/// One-time centered image promo after welcome onboarding (jpeg asset).
class FreeCallPopupService {
  static const String _prefix = 'free_call_popup_jpeg_shown';

  static String _k(String uid) => '${_prefix}_$uid';

  static Future<bool> hasShown(String uid) async {
    if (uid.trim().isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_k(uid.trim())) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markShown(String uid) async {
    if (uid.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_k(uid.trim()), true);
    } catch (_) {}
  }
}
