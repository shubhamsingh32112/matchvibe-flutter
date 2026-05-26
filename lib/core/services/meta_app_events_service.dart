import 'dart:io';

import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Pending Razorpay web checkout context for Purchase deduplication.
class MetaPendingCheckout {
  const MetaPendingCheckout({
    required this.sessionId,
    required this.packageId,
    required this.coins,
    required this.priceInr,
  });

  final String sessionId;
  final String packageId;
  final int coins;
  final int priceInr;
}

/// Meta App Events (Android) — single facade over [FacebookAppEvents].
class MetaAppEventsService {
  MetaAppEventsService._();

  static final FacebookAppEvents _events = FacebookAppEvents();
  static bool _initialized = false;
  static MetaPendingCheckout? _pendingCheckout;

  static final Set<String> _dedupeKeys = <String>{};
  static const int _dedupeMaxEntries = 200;

  /// Debug/profile: `flutter run --dart-define=META_ALLOW_DEBUG_EVENTS=true`
  static bool get allowDebugReporting => const bool.fromEnvironment(
        'META_ALLOW_DEBUG_EVENTS',
        defaultValue: false,
      );

  static bool get _hasCredentials {
    final appId = resolveAppId();
    return appId != null && appId.isNotEmpty && appId != '0';
  }

  /// Active when Android + credentials + (release or debug verify flag).
  static bool get isEnabled =>
      _initialized &&
      Platform.isAndroid &&
      _hasCredentials &&
      (kReleaseMode || allowDebugReporting);

  /// App ID: --dart-define > dotenv. Native SDK uses android/facebook.properties.
  static String? resolveAppId() {
    const fromDefine = String.fromEnvironment('META_APP_ID', defaultValue: '');
    if (fromDefine.trim().isNotEmpty) return fromDefine.trim();
    final fromEnv = (dotenv.env['META_APP_ID'] ?? '').trim();
    if (fromEnv.isNotEmpty) return fromEnv;
    return null;
  }

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (!Platform.isAndroid) {
      debugPrint('[META] Skipped: not Android');
      return;
    }
    if (!_hasCredentials) {
      debugPrint('[META] Skipped: META_APP_ID not set in .env or --dart-define');
      return;
    }
    if (!kReleaseMode && !allowDebugReporting) {
      debugPrint('[META] Skipped: debug build (use META_ALLOW_DEBUG_EVENTS to test)');
      return;
    }

    try {
      const debugLogs = bool.fromEnvironment(
        'META_APP_EVENTS_DEBUG',
        defaultValue: false,
      );
      if (debugLogs) {
        await _events.setAutoLogAppEventsEnabled(true);
      }
      await _events.activateApp();
      debugPrint('[META] App Events initialized');
    } catch (e, st) {
      debugPrint('[META] init failed: $e\n$st');
    }
  }

  static Future<void> setUserId(String? mongoUserId) async {
    if (!isEnabled || mongoUserId == null || mongoUserId.isEmpty) return;
    try {
      await _events.setUserID(mongoUserId);
    } catch (e) {
      debugPrint('[META] setUserID failed: $e');
    }
  }

  static Future<void> clearUserId() async {
    if (!isEnabled) return;
    try {
      await _events.clearUserID();
      await _events.clearUserData();
    } catch (e) {
      debugPrint('[META] clearUserID failed: $e');
    }
  }

  static void setPendingCheckout(MetaPendingCheckout checkout) {
    _pendingCheckout = checkout;
  }

  static MetaPendingCheckout? takePendingCheckout() {
    final pending = _pendingCheckout;
    _pendingCheckout = null;
    return pending;
  }

  static bool _rememberDedupeKey(String key) {
    if (key.isEmpty) return true;
    if (_dedupeKeys.contains(key)) return false;
    _dedupeKeys.add(key);
    if (_dedupeKeys.length > _dedupeMaxEntries) {
      _dedupeKeys.remove(_dedupeKeys.first);
    }
    return true;
  }

  static Future<void> logCompleteRegistration({
    String registrationMethod = 'google',
  }) async {
    if (!isEnabled) return;
    try {
      await _events.logCompletedRegistration(
        registrationMethod: registrationMethod,
      );
    } catch (e) {
      debugPrint('[META] CompleteRegistration failed: $e');
    }
  }

  static Future<void> logTutorialCompletion({bool success = true}) async {
    if (!isEnabled) return;
    try {
      await _events.logEvent(
        name: 'fb_mobile_tutorial_completion',
        parameters: {'fb_success': success ? '1' : '0'},
      );
    } catch (e) {
      debugPrint('[META] TutorialCompletion failed: $e');
    }
  }

  static Future<void> logViewContent({
    required String contentId,
    String contentType = 'creator_profile',
    String currency = 'INR',
    double? valueToSum,
  }) async {
    if (!isEnabled) return;
    try {
      await _events.logViewContent(
        id: contentId,
        type: contentType,
        currency: currency,
        price: valueToSum,
      );
    } catch (e) {
      debugPrint('[META] ViewContent failed: $e');
    }
  }

  static Future<void> logAddToCart({
    required String contentId,
    required double priceInr,
    String contentType = 'coin_pack',
    int quantity = 1,
  }) async {
    if (!isEnabled) return;
    try {
      await _events.logAddToCart(
        id: contentId,
        type: contentType,
        currency: 'INR',
        price: priceInr,
        content: quantity > 1
            ? {
                'id': contentId,
                'quantity': quantity,
              }
            : null,
      );
    } catch (e) {
      debugPrint('[META] AddToCart failed: $e');
    }
  }

  static Future<void> logInitiateCheckout({
    required String contentId,
    required double priceInr,
    String? sessionId,
    int numItems = 1,
  }) async {
    if (!isEnabled) return;
    final dedupeKey = sessionId != null && sessionId.isNotEmpty
        ? 'checkout:$sessionId'
        : 'checkout:$contentId:${DateTime.now().millisecondsSinceEpoch ~/ 60000}';
    if (!_rememberDedupeKey(dedupeKey)) return;
    try {
      final params = <String, dynamic>{
        FacebookAppEvents.paramNameContentId: contentId,
        FacebookAppEvents.paramNameContentType: 'coin_pack',
        FacebookAppEvents.paramNameCurrency: 'INR',
        FacebookAppEvents.paramNameNumItems: numItems,
        if (sessionId != null && sessionId.isNotEmpty)
          FacebookAppEvents.paramNameOrderId: sessionId,
      };
      await _events.logEvent(
        name: FacebookAppEvents.eventNameInitiatedCheckout,
        valueToSum: priceInr,
        parameters: params,
      );
    } catch (e) {
      debugPrint('[META] InitiateCheckout failed: $e');
    }
  }

  static Future<void> logPurchase({
    required double amountInr,
    required String contentId,
    required int coins,
    String? sessionId,
    String? dedupeId,
  }) async {
    if (!isEnabled) return;
    final key = dedupeId ??
        sessionId ??
        'purchase:$contentId:$coins:${amountInr.toStringAsFixed(0)}';
    if (!_rememberDedupeKey('purchase:$key')) return;
    try {
      await _events.logPurchase(
        amount: amountInr,
        currency: 'INR',
        parameters: {
          FacebookAppEvents.paramNameContentId: contentId,
          FacebookAppEvents.paramNameContentType: 'coin_pack',
          'coins': coins,
          if (sessionId != null && sessionId.isNotEmpty)
            FacebookAppEvents.paramNameOrderId: sessionId,
        },
      );
    } catch (e) {
      debugPrint('[META] Purchase failed: $e');
    }
  }

  static Future<void> logPurchaseFromPending({
    String? dedupeId,
    int? coinsAddedFromDeepLink,
  }) async {
    final pending = takePendingCheckout();
    if (pending == null) return;
    await logPurchase(
      amountInr: pending.priceInr.toDouble(),
      contentId: pending.packageId,
      coins: coinsAddedFromDeepLink ?? pending.coins,
      sessionId: pending.sessionId,
      dedupeId: dedupeId ?? pending.sessionId,
    );
  }

  static Future<void> logRated({
    required int rating,
    int maxRating = 5,
    String contentType = 'video_call',
  }) async {
    if (!isEnabled) return;
    try {
      await _events.logEvent(
        name: FacebookAppEvents.eventNameRated,
        valueToSum: rating.toDouble(),
        parameters: {
          'max_rating_value': maxRating,
          FacebookAppEvents.paramNameContentType: contentType,
        },
      );
    } catch (e) {
      debugPrint('[META] Rate failed: $e');
    }
  }

  static Future<void> logContact() async {
    if (!isEnabled) return;
    try {
      await _events.logEvent(name: 'Contact');
    } catch (e) {
      debugPrint('[META] Contact failed: $e');
    }
  }

  static Future<void> logUnlockAchievement({required String description}) async {
    if (!isEnabled) return;
    try {
      await _events.logEvent(
        name: 'fb_mobile_achievement_unlocked',
        parameters: {'fb_description': description},
      );
    } catch (e) {
      debugPrint('[META] UnlockAchievement failed: $e');
    }
  }

  static Future<void> logSpendCredits({
    required String contentId,
    required double amount,
    String contentType = 'video_call',
  }) async {
    if (!isEnabled) return;
    try {
      await _events.logEvent(
        name: 'fb_mobile_spent_credits',
        valueToSum: amount,
        parameters: {
          FacebookAppEvents.paramNameContentId: contentId,
          FacebookAppEvents.paramNameContentType: contentType,
          FacebookAppEvents.paramNameCurrency: 'INR',
        },
      );
    } catch (e) {
      debugPrint('[META] SpendCredits failed: $e');
    }
  }

  static Future<void> logCustomizeProduct({String? contentId}) async {
    if (!isEnabled) return;
    try {
      final params = contentId != null
          ? {FacebookAppEvents.paramNameContentId: contentId}
          : null;
      await _events.logEvent(
        name: 'CustomizeProduct',
        parameters: params,
      );
    } catch (e) {
      debugPrint('[META] CustomizeProduct failed: $e');
    }
  }

  static Future<void> logSubmitApplication({String? applicationType}) async {
    if (!isEnabled) return;
    try {
      final params = applicationType != null
          ? {'application_type': applicationType}
          : null;
      await _events.logEvent(
        name: 'SubmitApplication',
        parameters: params,
      );
    } catch (e) {
      debugPrint('[META] SubmitApplication failed: $e');
    }
  }
}
