import 'package:flutter/foundation.dart';
import '../../../app/router/app_router.dart';

/// Pure navigation helper — **no call logic, no state guessing**.
///
/// Navigation is invoked by [CallConnectionController] as soon as the call
/// enters `preparing` phase (for immediate outgoing / connecting UI).
class CallNavigationService {
  static bool _isOnCallScreen = false;

  /// Navigate to the call screen immediately (no [Call] object required).
  ///
  /// Returns `true` if navigation succeeded, `false` if already on call screen.
  static bool navigateToCallScreen() {
    if (_isOnCallScreen) {
      debugPrint('⏭️  [CALL NAV] Already on call screen');
      return false;
    }

    debugPrint('✅ [CALL NAV] Navigating to call screen');
    _isOnCallScreen = true;
    appRouter.push('/call');
    return true;
  }

  /// Navigate to home — used when a call ends or disconnects.
  static void navigateToHome() {
    debugPrint('✅ [CALL NAV] Navigating to /home');
    _isOnCallScreen = false;
    appRouter.go('/home');
  }

  /// Mark call screen as exited (without navigation).
  static void onCallScreenExited() {
    if (kDebugMode) {
      debugPrint('✅ [CALL NAV] Call screen exited');
    }
    _isOnCallScreen = false;
  }

  /// Whether the user is currently on the call screen.
  static bool get isOnCallScreen => _isOnCallScreen;
}
