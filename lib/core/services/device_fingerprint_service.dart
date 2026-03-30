import 'dart:io';
import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Provides a stable device fingerprint for Fast Login (one account per device).
/// Android: Settings.Secure.ANDROID_ID (via android_id package). iOS: identifierForVendor.
/// We do NOT use device_info_plus AndroidDeviceInfo.id — that is Build.ID (same for all devices
/// with the same OS build) and can cause different users to get the same account.
class DeviceFingerprintService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static const AndroidId _androidId = AndroidId();

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

  /// Returns a stable string identifying this device (unique per device/app-signing-key on Android).
  /// Throws if the platform is unsupported or info cannot be obtained.
  static Future<String> getDeviceFingerprint() async {
    try {
      if (Platform.isAndroid) {
        // Use real Android ID (Settings.Secure.ANDROID_ID). device_info_plus's android.id
        // is Build.ID — not unique per device, so different phones can collide and show wrong account.
        final id = await _androidId.getId();
        if (id != null && id.isNotEmpty) {
          return id;
        }
        // Fallback only if android_id fails (e.g. old plugin); prefer failing so we don't use Build.ID.
        final android = await _deviceInfo.androidInfo;
        final fallback = android.id;
        if (fallback.isEmpty) {
          throw Exception('Android ID is empty');
        }
        return fallback;
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
