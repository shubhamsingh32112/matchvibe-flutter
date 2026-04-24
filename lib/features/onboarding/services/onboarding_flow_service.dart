import 'package:shared_preferences/shared_preferences.dart';
import '../models/onboarding_step.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';

class OnboardingFlowService {
  static const String _welcomePrefix = 'onboarding_welcome_seen';
  static const String _bonusPrefix = 'onboarding_bonus_seen';
  static const String _permissionsPrefix = 'onboarding_permissions_seen';
  static const String _completedPrefix = 'onboarding_completed';

  static String _k(String prefix, String uid) => '${prefix}_$uid';

  static OnboardingStep? _fromServerStage(String? stage) {
    switch (stage) {
      case OnboardingStageContract.welcome:
        return OnboardingStep.welcome;
      case OnboardingStageContract.bonus:
        return OnboardingStep.bonus;
      case OnboardingStageContract.permission:
      case 'permissions':
        return OnboardingStep.permission;
      case OnboardingStageContract.completed:
        return OnboardingStep.completed;
      default:
        return null;
    }
  }

  static Future<OnboardingStep> nextStep({
    required String firebaseUid,
    required bool bonusAlreadyClaimed,
    String? serverStage,
  }) async {
    final serverStep = _fromServerStage(serverStage);
    if (AppConstants.enableServerOnboardingFlow && serverStep != null) {
      return serverStep;
    }

    final prefs = await SharedPreferences.getInstance();

    final completed = prefs.getBool(_k(_completedPrefix, firebaseUid)) ?? false;
    if (completed) return OnboardingStep.completed;

    final welcomeSeen = prefs.getBool(_k(_welcomePrefix, firebaseUid)) ?? false;
    if (!welcomeSeen) return OnboardingStep.welcome;

    final bonusSeen = prefs.getBool(_k(_bonusPrefix, firebaseUid)) ?? false;
    if (!bonusSeen && !bonusAlreadyClaimed) return OnboardingStep.bonus;

    final permissionsSeen =
        prefs.getBool(_k(_permissionsPrefix, firebaseUid)) ?? false;
    if (!permissionsSeen) return OnboardingStep.permission;

    return OnboardingStep.completed;
  }

  static Future<void> markWelcomeSeen(String firebaseUid) async {
    await _advanceOnServer(OnboardingStageContract.welcome);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_k(_welcomePrefix, firebaseUid), true);
  }

  static Future<void> markBonusSeen(String firebaseUid) async {
    await _advanceOnServer(OnboardingStageContract.bonus);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_k(_bonusPrefix, firebaseUid), true);
  }

  static Future<void> markPermissionsSeen(String firebaseUid) async {
    await _advanceOnServer(OnboardingStageContract.permission);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_k(_permissionsPrefix, firebaseUid), true);
  }

  static Future<void> markCompleted(String firebaseUid) async {
    await _advanceOnServer(OnboardingStageContract.completed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_k(_completedPrefix, firebaseUid), true);
  }

  static Future<void> clearLocalFlags(String firebaseUid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_k(_welcomePrefix, firebaseUid));
    await prefs.remove(_k(_bonusPrefix, firebaseUid));
    await prefs.remove(_k(_permissionsPrefix, firebaseUid));
    await prefs.remove(_k(_completedPrefix, firebaseUid));
  }

  static Future<void> _advanceOnServer(String stage) async {
    const retries = 3;
    for (var attempt = 1; attempt <= retries; attempt++) {
      try {
        await ApiClient()
            .post('/user/onboarding/stage', data: {'stage': stage})
            .timeout(const Duration(seconds: 4));
        return;
      } catch (e) {
        if (attempt == retries) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
      }
    }
  }
}
