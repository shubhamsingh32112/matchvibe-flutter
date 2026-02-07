import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:stream_video_flutter/stream_video_flutter.dart';
import '../../../app/router/app_router.dart';

/// Single source of truth for call navigation
/// 
/// 🔥 CRITICAL: Only ONE place navigates to /call
/// Prevents navigation race conditions and duplicate routes
/// 
/// The navigation callback is called SYNCHRONOUSLY before any navigation
/// to ensure IncomingCallListener can immediately clear its UI state.
class CallNavigationService {
  static bool _isOnCallScreen = false;
  static Call? _currentCall;
  
  // 🔥 CRITICAL: Callback to kill incoming call overlay IMMEDIATELY
  // This is called SYNCHRONOUSLY before navigation
  static void Function()? _onNavigatingToCall;
  
  // 🔧 POLISH: Callback when call screen exits (for defensive reset)
  static void Function()? _onCallScreenExited;

  /// Register callback to clear incoming call overlay
  /// Called SYNCHRONOUSLY when navigateToCall() is invoked
  static void setOnNavigatingToCall(void Function()? callback) {
    _onNavigatingToCall = callback;
  }
  
  /// Register callback for when call screen exits
  /// Used to reset _hasAcceptedCall defensively
  static void setOnCallScreenExited(void Function()? callback) {
    _onCallScreenExited = callback;
  }

  /// Navigate to call screen (single authority)
  /// 
  /// 🔥 CRITICAL: This method:
  /// 1. Calls _onNavigatingToCall SYNCHRONOUSLY (kills incoming UI)
  /// 2. Sets internal state
  /// 3. Pushes route
  /// 
  /// Returns true if navigation succeeded, false if already on call screen
  static bool navigateToCall(Call call) {
    // Idempotency: don't navigate again for the same call
    if (_isOnCallScreen && _currentCall?.id == call.id) {
      if (kDebugMode) {
        debugPrint('⏭️ [CALL NAV] Already on call screen for call: ${call.id}');
      }
      return false;
    }
    
    // 🔧 POLISH: Only log timing in debug mode
    int? startTime;
    if (kDebugMode) {
      startTime = DateTime.now().millisecondsSinceEpoch;
      debugPrint('🔥 [CALL NAV] ===== NAVIGATION START =====');
      debugPrint('   Call ID: ${call.id}');
    }

    // 🔥 STEP 1: Call the callback FIRST (SYNCHRONOUS)
    // This triggers setState in IncomingCallListener to kill the overlay
    _onNavigatingToCall?.call();
    
    // 🔥 STEP 2: Set internal state
    _isOnCallScreen = true;
    _currentCall = call;
    
    // 🔥 STEP 3: Push route
    appRouter.push('/call');
    
    if (kDebugMode && startTime != null) {
      final endTime = DateTime.now().millisecondsSinceEpoch;
      debugPrint('🔥 [CALL NAV] ===== NAVIGATION COMPLETE =====');
      debugPrint('   Duration: ${endTime - startTime}ms');
    }
    
    return true;
  }

  /// Mark call screen as exited
  /// 
  /// Called when VideoCallScreen is disposed or navigates away
  /// 🔧 POLISH: Also triggers callback for defensive reset of _hasAcceptedCall
  static void onCallScreenExited() {
    if (kDebugMode) {
      debugPrint('✅ [CALL NAV] Call screen exited');
    }
    _isOnCallScreen = false;
    _currentCall = null;
    
    // 🔧 POLISH: Notify IncomingCallListener to reset _hasAcceptedCall
    // This ensures clean state for the next call
    _onCallScreenExited?.call();
  }

  /// Check if currently on call screen
  static bool get isOnCallScreen => _isOnCallScreen;

  /// Get current call (if any)
  static Call? get currentCall => _currentCall;
  
  /// Get current call ID (for IncomingCallListener to check)
  static String? get currentCallId => _currentCall?.id;
}
