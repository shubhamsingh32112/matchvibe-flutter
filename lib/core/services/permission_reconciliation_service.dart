import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/video/services/permission_service.dart';
import '../api/api_client.dart';

class PermissionReconciliationService {
  static const String _keyPrefix = 'permission_reconcile_snapshot_v1';
  static const String _lastReconciledPrefix = 'permission_reconcile_last_sent_v1';
  static const int _minIntervalMs = 10 * 60 * 1000; // 10 minutes

  static String _key(String uid) => '${_keyPrefix}_$uid';
  static String _lastKey(String uid) => '${_lastReconciledPrefix}_$uid';

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  static Future<bool> shouldAttemptNow(String uid) async {
    final prefs = await _prefs();
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = prefs.getInt(_lastKey(uid)) ?? 0;
    return !(last > 0 && (now - last) < _minIntervalMs);
  }

  static Future<Map<String, String>> _currentStatuses() async {
    final cameraMicStatus = await PermissionService.cameraMicStatusForApi();
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    final notificationStatus = switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized => 'granted',
      AuthorizationStatus.provisional => 'granted',
      AuthorizationStatus.denied => 'denied',
      AuthorizationStatus.notDetermined => 'unknown',
    };
    return {
      'cameraMicStatus': cameraMicStatus,
      'notificationStatus': notificationStatus,
    };
  }

  static Future<bool> hasMeaningfulChange(String uid) async {
    final prefs = await _prefs();
    final raw = prefs.getString(_key(uid));
    final current = await _currentStatuses();
    if (raw == null || raw.isEmpty) {
      await prefs.setString(_key(uid), jsonEncode(current));
      return false;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await prefs.setString(_key(uid), jsonEncode(current));
        return false;
      }
      final prevCam = decoded['cameraMicStatus']?.toString() ?? '';
      final prevNoti = decoded['notificationStatus']?.toString() ?? '';
      final changed =
          prevCam != current['cameraMicStatus'] || prevNoti != current['notificationStatus'];
      if (changed) {
        await prefs.setString(_key(uid), jsonEncode(current));
      }
      return changed;
    } catch (_) {
      await prefs.setString(_key(uid), jsonEncode(current));
      return false;
    }
  }

  static Future<void> sendReconcile({
    required String uid,
    required String requestId,
    String? sessionId,
  }) async {
    final statuses = await _currentStatuses();
    await ApiClient().post(
      '/user/onboarding/permissions-reconcile',
      data: {
        'requestId': requestId,
        'cameraMicStatus': statuses['cameraMicStatus'],
        'notificationStatus': statuses['notificationStatus'],
      },
      headers: {
        if (sessionId != null) 'X-Onboarding-Session-Id': sessionId,
      },
    );
    final prefs = await _prefs();
    await prefs.setInt(_lastKey(uid), DateTime.now().millisecondsSinceEpoch);
  }
}

