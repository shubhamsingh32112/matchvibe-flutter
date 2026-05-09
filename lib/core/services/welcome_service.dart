import 'package:shared_preferences/shared_preferences.dart';

class WelcomeService {
  static const String _keyHasSeenWelcome = 'has_seen_welcome';
  static const String _keyWelcomeBackDialogShown = 'welcome_back_dialog_shown';
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
      await prefs.remove('${_keyWelcomeBackDialogShown}_$firebaseUid');
    } catch (_) {}
  }

  static Future<bool> hasWelcomeBackDialogBeenShown(String firebaseUid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('${_keyWelcomeBackDialogShown}_$firebaseUid') ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> markWelcomeBackDialogShown(String firebaseUid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('${_keyWelcomeBackDialogShown}_$firebaseUid', true);
    } catch (e) {
      // Ignore errors
    }
  }
}
