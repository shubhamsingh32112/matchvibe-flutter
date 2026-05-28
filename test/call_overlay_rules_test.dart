import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/features/video/providers/call_billing_provider.dart';
import 'package:zztherapy/features/video/providers/call_billing_selectors.dart';
import 'package:zztherapy/features/video/utils/call_overlay_rules.dart';

void main() {
  group('CallOverlayPolicy.shouldShowBillingSyncHint', () {
    test('returns true shortly after connect when billing not active', () {
      final billing = const CallBillingState(
        runtimeState: BillingRuntimeState.syncing,
        callStartTimeMs: null,
      );
      final shouldShow = CallOverlayPolicy.shouldShowBillingSyncHint(
        isConnected: true,
        billing: billing,
        connectedFor: const Duration(seconds: 3),
      );
      expect(shouldShow, isTrue);
    });

    test('returns false after timeout window', () {
      final billing = const CallBillingState(
        runtimeState: BillingRuntimeState.syncing,
        callStartTimeMs: null,
      );
      final shouldShow = CallOverlayPolicy.shouldShowBillingSyncHint(
        isConnected: true,
        billing: billing,
        connectedFor: const Duration(seconds: 20),
      );
      expect(shouldShow, isFalse);
    });

    test('returns false once billing is active', () {
      final billing = const CallBillingState(
        runtimeState: BillingRuntimeState.active,
        callStartTimeMs: 123,
      );
      final shouldShow = CallOverlayPolicy.shouldShowBillingSyncHint(
        isConnected: true,
        billing: billing,
        connectedFor: const Duration(seconds: 2),
      );
      expect(shouldShow, isFalse);
    });

    test('returns true when runtime regressed to recovering (reconnect wait)', () {
      final billing = const CallBillingState(
        runtimeState: BillingRuntimeState.recovering,
        callStartTimeMs: null,
      );
      final shouldShow = CallOverlayPolicy.shouldShowBillingSyncHint(
        isConnected: true,
        billing: billing,
        connectedFor: const Duration(seconds: 3),
      );
      expect(shouldShow, isTrue);
    });
  });

  group('CallOverlayPolicy.shouldShowBillingConnectionIssue', () {
    test('returns false while still in sync-hint window', () {
      final billing = const CallBillingState(
        runtimeState: BillingRuntimeState.syncing,
        callStartTimeMs: null,
      );
      final show = CallOverlayPolicy.shouldShowBillingConnectionIssue(
        isConnected: true,
        billing: billing,
        connectedFor: const Duration(seconds: 5),
      );
      expect(show, isFalse);
    });

    test('returns true after sync window when billing still not active', () {
      final billing = const CallBillingState(
        runtimeState: BillingRuntimeState.syncing,
        callStartTimeMs: null,
      );
      final show = CallOverlayPolicy.shouldShowBillingConnectionIssue(
        isConnected: true,
        billing: billing,
        connectedFor: const Duration(seconds: 15),
      );
      expect(show, isTrue);
    });

    test('returns false when billing became active', () {
      final billing = const CallBillingState(
        runtimeState: BillingRuntimeState.active,
        callStartTimeMs: 1,
      );
      final show = CallOverlayPolicy.shouldShowBillingConnectionIssue(
        isConnected: true,
        billing: billing,
        connectedFor: const Duration(seconds: 20),
      );
      expect(show, isFalse);
    });
  });

  group('shouldShowLastTenSecondsHeartbeat', () {
    test('returns true for regular user when remaining seconds are 1..10', () {
      final billing = const CallBillingState(
        runtimeState: BillingRuntimeState.active,
        remainingSeconds: 9,
      );

      final shouldShow = shouldShowLastTenSecondsHeartbeat(
        isCreator: false,
        billing: billing,
      );

      expect(shouldShow, isTrue);
    });

    test('returns false when remainingSeconds is null', () {
      final billing = const CallBillingState(
        runtimeState: BillingRuntimeState.active,
        remainingSeconds: null,
      );

      final shouldShow = shouldShowLastTenSecondsHeartbeat(
        isCreator: false,
        billing: billing,
      );

      expect(shouldShow, isFalse);
    });

    test('returns false when remainingSeconds is 0', () {
      final billing = const CallBillingState(
        runtimeState: BillingRuntimeState.active,
        remainingSeconds: 0,
      );

      final shouldShow = shouldShowLastTenSecondsHeartbeat(
        isCreator: false,
        billing: billing,
      );

      expect(shouldShow, isFalse);
    });

    test('returns false when remainingSeconds is greater than 10', () {
      final billing = const CallBillingState(
        runtimeState: BillingRuntimeState.active,
        remainingSeconds: 11,
      );

      final shouldShow = shouldShowLastTenSecondsHeartbeat(
        isCreator: false,
        billing: billing,
      );

      expect(shouldShow, isFalse);
    });

    test('returns false for creators even in final 10 seconds', () {
      final billing = const CallBillingState(
        runtimeState: BillingRuntimeState.active,
        remainingSeconds: 8,
      );

      final shouldShow = shouldShowLastTenSecondsHeartbeat(
        isCreator: true,
        billing: billing,
      );

      expect(shouldShow, isFalse);
    });
  });
}
