import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'checkin_popup_gate.dart';
import 'checkin_service.dart';

/// Registers first-party FCM tokens with MatchVibe backend (not Stream).
class CheckInPushTokenService {
  CheckInPushTokenService._();

  static final CheckInService _service = CheckInService();
  static bool _refreshListenerAttached = false;

  static String get _platform => Platform.isIOS ? 'ios' : 'android';

  /// Register current FCM token if notification permission is already granted.
  /// Only for consumer `role == user`.
  static Future<void> syncIfAuthorized({required String? role}) async {
    if (role != 'user') return;
    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      final authorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!authorized) {
        debugPrint('🔕 [CHECKIN] Push not authorized — skip token sync');
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      await _service.registerPushToken(token: token, platform: _platform);
      _ensureRefreshListener();
      debugPrint('✅ [CHECKIN] FCM token registered with backend');
    } catch (e) {
      debugPrint('⚠️ [CHECKIN] syncIfAuthorized failed: $e');
    }
  }

  static void _ensureRefreshListener() {
    if (_refreshListenerAttached) return;
    _refreshListenerAttached = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      try {
        await _service.registerPushToken(token: token, platform: _platform);
      } catch (e) {
        debugPrint('⚠️ [CHECKIN] token refresh register failed: $e');
      }
    });
  }

  /// Unregister current token and clear popup gate (logout).
  static Future<void> clearOnLogout() async {
    CheckInPopupGate.reset();
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _service.unregisterPushToken(token);
      }
    } catch (e) {
      debugPrint('⚠️ [CHECKIN] clearOnLogout failed: $e');
    }
  }
}
