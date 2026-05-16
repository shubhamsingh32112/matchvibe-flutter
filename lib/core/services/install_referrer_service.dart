import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../utils/referral_code_format.dart';

/// Reads Google Play Install Referrer once per install (Android) to recover `ref=CODE`.
class InstallReferrerService {
  InstallReferrerService._();

  /// Returns a normalized referral code from Play Store install referrer, or null.
  static Future<String?> tryConsumeReferralCode() async {
    if (!Platform.isAndroid) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(AppConstants.keyInstallReferrerConsumed) == true) {
        return null;
      }

      await prefs.setBool(AppConstants.keyInstallReferrerConsumed, true);

      final details = await PlayInstallReferrer.installReferrer;
      final raw = details.installReferrer?.trim();
      if (raw == null || raw.isEmpty) {
        if (kDebugMode) {
          debugPrint('📦 [INSTALL_REFERRER] Empty referrer string');
        }
        return null;
      }

      final code = _parseReferralCode(raw);
      if (code == null) {
        if (kDebugMode) {
          debugPrint('📦 [INSTALL_REFERRER] No valid code in: $raw');
        }
        return null;
      }

      if (kDebugMode) {
        debugPrint('📦 [INSTALL_REFERRER] Parsed code: $code');
      }
      return code;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [INSTALL_REFERRER] Failed: $e');
      }
      return null;
    }
  }

  /// Parses `ref=CODE` (Play Store referrer param) or a bare valid code.
  static String? _parseReferralCode(String raw) {
    var decoded = raw;
    try {
      decoded = Uri.decodeComponent(raw);
    } catch (_) {
      decoded = raw;
    }

    final lower = decoded.toLowerCase();
    String? candidate;
    const prefix = 'ref=';
    final idx = lower.indexOf(prefix);
    if (idx >= 0) {
      candidate = decoded.substring(idx + prefix.length).trim();
      final amp = candidate.indexOf('&');
      if (amp >= 0) {
        candidate = candidate.substring(0, amp).trim();
      }
    } else {
      candidate = decoded.trim();
    }

    if (candidate.isEmpty) return null;
    final upper = candidate.toUpperCase();
    if (!ReferralCodeFormat.isValid(upper)) return null;
    return upper;
  }
}
