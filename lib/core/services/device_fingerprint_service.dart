import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Provides a stable device fingerprint for Fast Login (one account per device).
/// Android: androidId. iOS: identifierForVendor.
class DeviceFingerprintService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Returns true if Fast Login is allowed on this device.
  /// Disables Fast Login on Android emulators to prevent emulator-farm abuse.
  static Future<bool> isFastLoginAllowed() async {
    if (!Platform.isAndroid) return true; // iOS: no emulator check (simulators less abused)
    try {
      final android = await _deviceInfo.androidInfo;
      if (!android.isPhysicalDevice) return false;
      // Additional lightweight emulator signals (generic SDK / goldfish)
      final model = android.model.toLowerCase();
      final fingerprint = android.fingerprint.toLowerCase();
      final hardware = android.hardware.toLowerCase();
      final emulatorIndicators = model.contains('sdk') ||
          fingerprint.contains('generic') ||
          hardware.contains('goldfish');
      return !emulatorIndicators;
    } catch (_) {
      return false; // Fail closed: disallow if we can't determine
    }
  }

  /// Returns a stable string identifying this device.
  /// Throws if the platform is unsupported or info cannot be obtained.
  static Future<String> getDeviceFingerprint() async {
    try {
      if (Platform.isAndroid) {
        final android = await _deviceInfo.androidInfo;
        final id = android.id;
        if (id.isEmpty) {
          throw Exception('Android ID is empty');
        }
        return id;
      }
      if (Platform.isIOS) {
        final ios = await _deviceInfo.iosInfo;
        final id = ios.identifierForVendor;
        if (id == null || id.isEmpty) {
          throw Exception('iOS identifierForVendor is not available');
        }
        return id;
      }
    } catch (e, st) {
      debugPrint('DeviceFingerprintService error: $e');
      debugPrint('$st');
      rethrow;
    }
    throw UnsupportedError('Fast Login is only supported on Android and iOS');
  }
}
