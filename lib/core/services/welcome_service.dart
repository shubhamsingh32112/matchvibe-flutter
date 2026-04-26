import 'package:shared_preferences/shared_preferences.dart';

class WelcomeService {
  static const String _keyHasSeenWelcome = 'has_seen_welcome';
  static const String _keyBonusDialogShown = 'welcome_bonus_dialog_shown';
  static String _welcomeKey(String firebaseUid) =>
      '${_keyHasSeenWelcome}_$firebaseUid';

  /// Check if user has seen the welcome dialog
  static Future<bool> hasSeenWelcome([String? firebaseUid]) async {
    try {
      if (firebaseUid == null || firebaseUid.isEmpty) return false;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_welcomeKey(firebaseUid)) ?? false;
    } catch (e) {
      // If there's an error, assume they haven't seen it
      return false;
    }
  }

  /// Mark that user has seen the welcome dialog
  static Future<void> markWelcomeAsSeen([String? firebaseUid]) async {
    try {
      if (firebaseUid == null || firebaseUid.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_welcomeKey(firebaseUid), true);
    } catch (e) {
      // Ignore errors
    }
  }

  /// Check if the welcome bonus dialog has already been shown to this user
  /// (regardless of whether they claimed or declined).
  static Future<bool> hasBonusDialogBeenShown(String firebaseUid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('${_keyBonusDialogShown}_$firebaseUid') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Mark that the welcome bonus dialog has been shown to this user.
  /// Called when the dialog is displayed — ensures it never pops up again.
  static Future<void> markBonusDialogShown(String firebaseUid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('${_keyBonusDialogShown}_$firebaseUid', true);
    } catch (e) {
      // Ignore errors
    }
  }

  /// Reset welcome status (useful for testing)
  static Future<void> resetWelcomeStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyHasSeenWelcome);
    } catch (e) {
      // Ignore errors
    }
  }

  static Future<void> clearWelcomeStatusForUser(String firebaseUid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_welcomeKey(firebaseUid));
      await prefs.remove('${_keyBonusDialogShown}_$firebaseUid');
    } catch (_) {}
  }
}
