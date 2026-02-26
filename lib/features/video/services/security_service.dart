import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';

/// Service for platform-specific security features
/// 
/// - Android: FLAG_SECURE to block screenshots/recording
/// - iOS: Screen capture detection with blur/disconnect
class SecurityService {
  static const MethodChannel _channel = MethodChannel('com.zztherapy/security');
  static Function(bool)? _onScreenCaptureChanged;
  static bool _isInitialized = false;

  /// Initialize app-wide security protections.
  ///
  /// This is intended to run once during app startup so capture protection
  /// applies to every screen for all roles.
  static Future<void> initializeAppSecurity() async {
    if (_isInitialized) return;

    try {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onScreenCaptureChanged') {
          final isCaptured = call.arguments as bool;
          debugPrint('🔒 [SECURITY] Screen capture changed: $isCaptured');
          _onScreenCaptureChanged?.call(isCaptured);
        }
      });

      if (Platform.isAndroid) {
        await _channel.invokeMethod('setSecureFlag', {'enable': true});
        debugPrint('🔒 [SECURITY] Android FLAG_SECURE enabled app-wide');
      } else if (Platform.isIOS) {
        await _channel.invokeMethod('startScreenCaptureDetection');
        debugPrint('🔒 [SECURITY] iOS capture protection enabled app-wide');
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ [SECURITY] Error initializing app security: $e');
    }
  }

  /// Enable security for video calls (block screenshots/recording)
  /// 
  /// Android: Sets FLAG_SECURE on window
  /// iOS: Starts screen capture detection
  static Future<void> enableCallSecurity() async {
    await initializeAppSecurity();
  }

  /// Disable security (restore normal behavior)
  static Future<void> disableCallSecurity() async {
    // Intentionally no-op: security must remain enabled app-wide.
    debugPrint('🔒 [SECURITY] disableCallSecurity ignored (app-wide protection active)');
  }

  /// Set callback for screen capture detection (iOS)
  /// 
  /// Called when screen recording starts/stops
  /// Should blur UI or disconnect call when isCaptured is true
  static void setOnScreenCaptureChanged(Function(bool isCaptured) callback) {
    _onScreenCaptureChanged = callback;
  }

  static void clearOnScreenCaptureChanged() {
    _onScreenCaptureChanged = null;
  }
}
