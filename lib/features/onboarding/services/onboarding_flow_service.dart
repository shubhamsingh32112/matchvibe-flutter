import 'package:shared_preferences/shared_preferences.dart';
import '../models/onboarding_step.dart';

class OnboardingFlowService {
  static const String _welcomePrefix = 'onboarding_welcome_seen';
  static const String _bonusPrefix = 'onboarding_bonus_seen';
  static const String _permissionsPrefix = 'onboarding_permissions_seen';
  static const String _completedPrefix = 'onboarding_completed';

  static String _k(String prefix, String uid) => '${prefix}_$uid';

  static Future<OnboardingStep> nextStep({
    required String firebaseUid,
    required bool bonusAlreadyClaimed,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final completed = prefs.getBool(_k(_completedPrefix, firebaseUid)) ?? false;
    if (completed) return OnboardingStep.completed;

    final welcomeSeen = prefs.getBool(_k(_welcomePrefix, firebaseUid)) ?? false;
    if (!welcomeSeen) return OnboardingStep.welcome;

    final bonusSeen = prefs.getBool(_k(_bonusPrefix, firebaseUid)) ?? false;
    if (!bonusSeen && !bonusAlreadyClaimed) return OnboardingStep.bonus;

    final permissionsSeen =
        prefs.getBool(_k(_permissionsPrefix, firebaseUid)) ?? false;
    if (!permissionsSeen) return OnboardingStep.permissionsIntro;

    return OnboardingStep.completed;
  }

  static Future<void> markWelcomeSeen(String firebaseUid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_k(_welcomePrefix, firebaseUid), true);
  }

  static Future<void> markBonusSeen(String firebaseUid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_k(_bonusPrefix, firebaseUid), true);
  }

  static Future<void> markPermissionsSeen(String firebaseUid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_k(_permissionsPrefix, firebaseUid), true);
  }

  static Future<void> markCompleted(String firebaseUid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_k(_completedPrefix, firebaseUid), true);
  }
}
