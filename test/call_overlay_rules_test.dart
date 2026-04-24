import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/features/video/providers/call_billing_provider.dart';
import 'package:zztherapy/features/video/utils/call_overlay_rules.dart';

void main() {
  group('shouldShowLastTenSecondsHeartbeat', () {
    test('returns true for regular user when remaining seconds are 1..10', () {
      final billing = const CallBillingState(isActive: true, remainingSeconds: 9);

      final shouldShow = shouldShowLastTenSecondsHeartbeat(
        isCreator: false,
        billing: billing,
      );

      expect(shouldShow, isTrue);
    });

    test('returns false when remainingSeconds is null', () {
      final billing = const CallBillingState(isActive: true, remainingSeconds: null);

      final shouldShow = shouldShowLastTenSecondsHeartbeat(
        isCreator: false,
        billing: billing,
      );

      expect(shouldShow, isFalse);
    });

    test('returns false when remainingSeconds is 0', () {
      final billing = const CallBillingState(isActive: true, remainingSeconds: 0);

      final shouldShow = shouldShowLastTenSecondsHeartbeat(
        isCreator: false,
        billing: billing,
      );

      expect(shouldShow, isFalse);
    });

    test('returns false when remainingSeconds is greater than 10', () {
      final billing = const CallBillingState(isActive: true, remainingSeconds: 11);

      final shouldShow = shouldShowLastTenSecondsHeartbeat(
        isCreator: false,
        billing: billing,
      );

      expect(shouldShow, isFalse);
    });

    test('returns false for creators even in final 10 seconds', () {
      final billing = const CallBillingState(isActive: true, remainingSeconds: 8);

      final shouldShow = shouldShowLastTenSecondsHeartbeat(
        isCreator: true,
        billing: billing,
      );

      expect(shouldShow, isFalse);
    });
  });
}
