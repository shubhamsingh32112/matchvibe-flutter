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

  test('onboarding follows local fallback order when no server stage', () async {
    final first = await OnboardingFlowService.nextStep(
      firebaseUid: uid,
      bonusAlreadyClaimed: false,
      serverStage: null,
    );
    expect(first, OnboardingStep.welcome);
  });

  test('server stage maps to permission step', () async {
    final step = await OnboardingFlowService.nextStep(
      firebaseUid: uid,
      bonusAlreadyClaimed: true,
      serverStage: 'permission',
    );
    expect(step, OnboardingStep.permission);
  });

  test('server completed stage wins over local flags', () async {
    final step = await OnboardingFlowService.nextStep(
      firebaseUid: uid,
      bonusAlreadyClaimed: false,
      serverStage: 'completed',
    );
    expect(step, OnboardingStep.completed);
  });

  test('local override wins over stale server stage', () async {
    OnboardingFlowService.setLocalStageOverride(
      firebaseUid: uid,
      step: OnboardingStep.permission,
    );
    final step = await OnboardingFlowService.nextStep(
      firebaseUid: uid,
      bonusAlreadyClaimed: false,
      serverStage: 'welcome',
    );
    expect(step, OnboardingStep.permission);
  });

  test('local override clears when server catches up', () async {
    OnboardingFlowService.setLocalStageOverride(
      firebaseUid: uid,
      step: OnboardingStep.permission,
    );
    await OnboardingFlowService.nextStep(
      firebaseUid: uid,
      bonusAlreadyClaimed: false,
      serverStage: 'permission',
    );
    final next = await OnboardingFlowService.nextStep(
      firebaseUid: uid,
      bonusAlreadyClaimed: false,
      serverStage: 'welcome',
    );
    expect(next, OnboardingStep.welcome);
  });
}
