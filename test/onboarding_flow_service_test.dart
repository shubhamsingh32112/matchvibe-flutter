import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zztherapy/features/onboarding/models/onboarding_step.dart';
import 'package:zztherapy/features/onboarding/services/onboarding_flow_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uid = 'test-user';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'onboarding progresses through welcome -> bonus -> permissions',
    () async {
      final first = await OnboardingFlowService.nextStep(
        firebaseUid: uid,
        bonusAlreadyClaimed: false,
      );
      expect(first, OnboardingStep.welcome);

      await OnboardingFlowService.markWelcomeSeen(uid);
      final second = await OnboardingFlowService.nextStep(
        firebaseUid: uid,
        bonusAlreadyClaimed: false,
      );
      expect(second, OnboardingStep.bonus);

      await OnboardingFlowService.markBonusSeen(uid);
      final third = await OnboardingFlowService.nextStep(
        firebaseUid: uid,
        bonusAlreadyClaimed: false,
      );
      expect(third, OnboardingStep.permission);
    },
  );

  test('onboarding completes when all steps are marked done', () async {
    await OnboardingFlowService.markWelcomeSeen(uid);
    await OnboardingFlowService.markBonusSeen(uid);
    await OnboardingFlowService.markPermissionsSeen(uid);
    await OnboardingFlowService.markCompleted(uid);

    final step = await OnboardingFlowService.nextStep(
      firebaseUid: uid,
      bonusAlreadyClaimed: true,
    );
    expect(step, OnboardingStep.completed);
  });
}
