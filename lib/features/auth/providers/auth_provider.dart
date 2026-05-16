import 'dart:async' show Completer, unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/api/api_client.dart';
import '../../../core/images/image_asset_view.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../chat/services/chat_service.dart';
import '../../../core/services/availability_socket_service.dart';
import '../../../core/services/device_fingerprint_service.dart';
import '../../../core/services/install_referrer_service.dart';
import '../../../core/services/google_sign_in_service.dart';
import '../../../shared/models/user_model.dart';
import '../../../core/utils/referral_apply_messages.dart';
import '../../../core/utils/referral_code_format.dart';
import '../../referral/services/referral_service.dart';
import '../../../app/router/app_router.dart';
import '../../../shared/widgets/app_toast.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthState {
  final User? firebaseUser;
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final String? verificationId;
  final int? resendToken;
  final String? phoneNumber;
  final bool createdNow;
  final bool showWelcomeBackDialog;

  AuthState({
    this.firebaseUser,
    this.user,
    this.isLoading = false,
    this.error,
    this.verificationId,
    this.resendToken,
    this.phoneNumber,
    this.createdNow = false,
    this.showWelcomeBackDialog = false,
  });

  bool get isAuthenticated => firebaseUser != null && user != null;

  AuthState copyWith({
    User? firebaseUser,
    UserModel? user,
    bool? isLoading,
    String? error,
    String? verificationId,
    int? resendToken,
    String? phoneNumber,
    bool? createdNow,
    bool? showWelcomeBackDialog,
  }) {
    return AuthState(
      firebaseUser: firebaseUser ?? this.firebaseUser,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdNow: createdNow ?? this.createdNow,
      showWelcomeBackDialog: showWelcomeBackDialog ?? this.showWelcomeBackDialog,
    );
  }
}

enum PhoneAuthStartStatus {
  codeSent,
  autoVerified,
  blocked,
  syncingBackend,
  alreadyAuthenticated,
  failed,
}

class PhoneAuthStartResult {
  final bool success;
  final PhoneAuthStartStatus status;
  final String? error;
  final int? retryAfterSeconds;

  const PhoneAuthStartResult({
    required this.success,
    required this.status,
    this.error,
    this.retryAfterSeconds,
  });
}

class AuthNotifier extends StateNotifier<AuthState> {
  FirebaseAuth? _auth;
  ApiClient get _apiClient => ApiClient();
  bool _isInitializing = false;

  // Referral: optional code to apply on first signup (cleared after sync)
  String? _pendingReferralCode;
  final Completer<void> _referralHydrateCompleter = Completer<void>();

  // 🔥 FIX: Guards to prevent duplicate operations
  bool _otpVerified = false; // Prevents multiple OTP verify attempts
  bool _isSyncingToBackend = false; // Prevents duplicate backend syncs
  String? _lastSyncedUid; // Tracks which UID was last synced
  bool _phoneVerificationInProgress =
      false; // Prevents duplicate verifyPhoneNumber calls
  DateTime? _lastVerificationAttempt; // Track last verification request time
  DateTime? _phoneBlockedUntil; // Explicit hard block for too-many-requests
  static const Duration _verificationCooldown = Duration(
    seconds: 30,
  ); // Minimum time between requests
  static const Duration _tooManyRequestsCooldown = Duration(minutes: 5);
  /// Must exceed Firebase SMS / `verifyPhoneNumber` latency on slow networks.
  /// Previously 30s caused false timeouts while `codeSent` was still pending.
  static const Duration _phoneVerificationUserTimeout = Duration(seconds: 90);

  // 🔥 FIX: Test phone numbers (for Firebase test authentication)
  // These numbers use manual OTP flow, no SMS auto-retrieval
  static const Set<String> _testPhoneNumbers = {
    '+919999999999',
    '+911234567890',
    '+15555555555', // Common US test number
  };

  /// Check if a phone number is a Firebase test number
  bool _isTestNumber(String phone) {
    return _testPhoneNumbers.contains(phone);
  }

  /// Strict E.164 for Firebase (`+[country][subscriber]`, digits only after +).
  String? _normalizePhoneE164(String raw) {
    final s = raw.trim().replaceAll(RegExp(r'[\s\-.]'), '');
    if (s.isEmpty) return null;
    if (!s.startsWith('+')) return null;
    if (s.length < 10 || s.length > 17) return null;
    if (!RegExp(r'^\+\d{9,16}$').hasMatch(s)) return null;
    return s;
  }

  AuthNotifier() : super(AuthState()) {
    _initialize();
  }

  @visibleForTesting
  AuthNotifier.testInitial(AuthState initial) : super(initial) {
    _isInitializing = true;
  }

  Future<void> _initialize() async {
    if (_isInitializing) {
      debugPrint('⏳ [AUTH] Already initializing, skipping...');
      return;
    }
    _isInitializing = true;

    debugPrint('🔧 [AUTH] Initializing AuthNotifier...');

    try {
      // Check if Firebase is already initialized
      try {
        _auth = FirebaseAuth.instance;
        debugPrint('✅ [AUTH] Firebase Auth instance retrieved');
        _init();
        _isInitializing = false;
        return;
      } catch (e) {
        // Firebase not initialized yet, try to initialize
        debugPrint('⚠️  [AUTH] Firebase not initialized, waiting...');
        debugPrint('   Error: $e');
      }

      // Wait for Firebase to be initialized (should be done in main())
      // Give it a moment
      await Future.delayed(const Duration(milliseconds: 100));

      // Try again
      try {
        _auth = FirebaseAuth.instance;
        debugPrint('✅ [AUTH] Firebase Auth instance retrieved after wait');
        _init();
      } catch (e) {
        debugPrint('❌ [AUTH] Firebase Auth still not available: $e');
        debugPrint('   💡 Please run: flutterfire configure');
        state = state.copyWith(
          error: kDebugMode
              ? 'Firebase initialization required. Run flutterfire configure.'
              : 'Sign-in isn\'t ready yet. Please restart the app or contact support.',
        );
        _completeReferralHydration();
      }
    } finally {
      _isInitializing = false;
      debugPrint('🏁 [AUTH] Initialization complete');
    }
  }

  /// Login UI should await this before reading [peekPendingReferralCode].
  Future<void> waitForReferralHydration() => _referralHydrateCompleter.future;

  void _completeReferralHydration() {
    if (!_referralHydrateCompleter.isCompleted) {
      _referralHydrateCompleter.complete();
    }
  }

  Future<void> _init() async {
    if (_auth == null) {
      _completeReferralHydration();
      return;
    }

    await _hydratePendingReferralFromPrefs();

    // 🔥 CRITICAL: Disable app verification in debug mode
    // Skips Play Integrity, reCAPTCHA, cert hash checks
    // Does NOT affect production builds
    if (kDebugMode) {
      await _auth!.setSettings(appVerificationDisabledForTesting: true);
      debugPrint(
        '🧪 [AUTH] App verification DISABLED for testing (debug only)',
      );
    }

    debugPrint('🔐 [AUTH] Setting up auth state listener...');

    // Keep SharedPreferences Bearer token aligned with Firebase refresh cycles (~1h).
    _auth!.idTokenChanges().listen((User? user) async {
      if (user == null) return;
      try {
        final token = await user.getIdToken();
        if (token != null && token.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(AppConstants.keyAuthToken, token);
          ApiClient.setAuthTokenMemory(token);
          if (kDebugMode) {
            debugPrint('💾 [AUTH] ID token persisted from idTokenChanges');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️  [AUTH] idTokenChanges persist skipped: $e');
        }
      }
    });

    _auth!.authStateChanges().listen((user) async {
      if (user != null) {
        debugPrint('👤 [AUTH] Auth state changed: User logged in');
        debugPrint('   📧 Email: ${user.email ?? "N/A"}');
        debugPrint('   📱 Phone: ${user.phoneNumber ?? "N/A"}');
        debugPrint('   🆔 UID: ${user.uid}');

        // 🔥 FIX 2 & 3: Guard against duplicate syncs
        // Only sync if:
        // 1. We're not already syncing
        // 2. This is a different user than last synced (or first sync)
        // 3. We don't already have this user in state
        if (_isSyncingToBackend) {
          debugPrint(
            '⏭️ [AUTH] Already syncing to backend, skipping duplicate',
          );
          return;
        }

        if (_lastSyncedUid == user.uid && state.user != null) {
          debugPrint('⏭️ [AUTH] User ${user.uid} already synced, skipping');
          // Still update firebaseUser in state if needed
          if (state.firebaseUser?.uid != user.uid) {
            state = state.copyWith(firebaseUser: user);
          }
          return;
        }

        await _syncUserToBackend(user);
      } else {
        debugPrint('🚪 [AUTH] Auth state changed: User logged out');
        // 🔥 FIX: Reset all guards on logout
        _otpVerified = false;
        _isSyncingToBackend = false;
        _lastSyncedUid = null;
        _phoneVerificationInProgress = false;
        _phoneBlockedUntil = null;
        ApiClient.clearAuthTokenMemory();
        state = AuthState();
      }
    });
  }

  Future<void> _syncUserToBackend(User firebaseUser) async {
    // 🔥 FIX: Prevent duplicate syncs
    if (_isSyncingToBackend) {
      debugPrint('⏭️ [AUTH] _syncUserToBackend already in progress, skipping');
      return;
    }

    _isSyncingToBackend = true;
    String? pendingReferralForLogin;
    var referralDispositionFinalized = false;

    try {
      // Determine auth method for logging context
      final authMethod =
          firebaseUser.providerData
              .where((p) => p.providerId == 'phone')
              .isNotEmpty
          ? 'PHONE'
          : 'OTHER';

      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('🔄 [AUTH] Starting backend sync');
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('   🔐 Auth Method: $authMethod');
      debugPrint('   🆔 Firebase UID: ${firebaseUser.uid}');
      debugPrint('   📧 Email: ${firebaseUser.email ?? "N/A"}');
      debugPrint('   📱 Phone: ${firebaseUser.phoneNumber ?? "N/A"}');

      // 🔥 FIX: Always set firebaseUser in state, even before sync attempt.
      // This ensures state.firebaseUser is available for retry if sync fails.
      state = state.copyWith(
        isLoading: true,
        error: null,
        firebaseUser: firebaseUser,
      );

      // CRITICAL: Test backend connectivity before attempting login
      debugPrint('🧪 [AUTH] Testing backend connectivity...');
      final apiClient = ApiClient();
      final isConnected = await apiClient.testConnection();

      if (!isConnected) {
        debugPrint('❌ [AUTH] Backend connectivity test failed');
        debugPrint(
          '   💡 Backend is not reachable at: ${AppConstants.baseUrl}',
        );
        debugPrint('   🧪 Test URL: ${AppConstants.healthCheckUrl}');
        debugPrint('   📋 Troubleshooting:');
        debugPrint('      1. Verify backend is running (check terminal)');
        debugPrint('      2. Check IP address: ${AppConstants.baseUrl}');
        debugPrint('      3. Test in browser: ${AppConstants.healthCheckUrl}');
        debugPrint('      4. Ensure phone and laptop are on same Wi-Fi');
        debugPrint('      5. Disable mobile data on phone');
        debugPrint('      6. Check firewall settings');

        throw Exception(
          'Backend server is not reachable. Please check:\n'
          '• Backend is running\n'
          '• Correct IP address: ${AppConstants.baseUrl}\n'
          '• Phone and laptop are on same Wi-Fi\n'
          '• Mobile data is disabled\n'
          '• Test in browser: ${AppConstants.healthCheckUrl}',
        );
      }

      debugPrint('✅ [AUTH] Backend connectivity test passed');

      debugPrint('🎫 [AUTH] Requesting Firebase ID token...');
      final tokenStartTime = DateTime.now();
      final token = await firebaseUser.getIdToken();
      final tokenDuration = DateTime.now().difference(tokenStartTime);

      if (token == null) {
        debugPrint('❌ [AUTH] Failed to get authentication token');
        debugPrint(
          '   ⏱️  Token request duration: ${tokenDuration.inMilliseconds}ms',
        );
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to get authentication token',
        );
        return;
      }
      debugPrint('✅ [AUTH] Firebase ID token retrieved');
      debugPrint(
        '   ⏱️  Token request duration: ${tokenDuration.inMilliseconds}ms',
      );
      debugPrint('   📏 Token length: ${token.length} characters');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyAuthToken, token);
      ApiClient.setAuthTokenMemory(token);
      debugPrint('💾 [AUTH] Token saved to local storage');

      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('📡 [AUTH] Sending login request to backend...');
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('   🌐 Base URL: ${AppConstants.baseUrl}');
      debugPrint('   🌐 Endpoint: /auth/login');
      debugPrint('   🌐 Full URL: ${AppConstants.baseUrl}/auth/login');
      debugPrint('   🔑 Auth token: Present (${token.length} chars)');
      debugPrint('   💡 Make sure backend is running and accessible');
      // Optional device fingerprint for login (skip emulators / abuse).
      final Map<String, dynamic> loginBody = {};
      try {
        if (await DeviceFingerprintService.shouldSendDeviceFingerprintForLogin()) {
          final fp = await DeviceFingerprintService.getDeviceFingerprint();
          if (fp.isNotEmpty) loginBody['deviceFingerprint'] = fp;
        }
      } catch (_) {
        // Emulator or unsupported platform — omit deviceFingerprint
      }
      pendingReferralForLogin =
          (_pendingReferralCode != null &&
              ReferralCodeFormat.isValid(_pendingReferralCode!))
          ? _pendingReferralCode!.trim().toUpperCase()
          : null;
      if (pendingReferralForLogin != null) {
        loginBody['referralCode'] = pendingReferralForLogin;
      }
      final apiStartTime = DateTime.now();
      final response = await _apiClient.post(
        '/auth/login',
        data: loginBody.isNotEmpty ? loginBody : null,
      );
      final apiDuration = DateTime.now().difference(apiStartTime);
      debugPrint('📥 [AUTH] Backend response received');
      debugPrint('   ⏱️  API call duration: ${apiDuration.inMilliseconds}ms');
      debugPrint('   🔢 Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = response.data['data'] as Map<String, dynamic>;
        final meta = responseData['meta'];
        final showWelcomeBackDialog =
            meta is Map<String, dynamic> && meta['showWelcomeBackDialog'] == true;
        String? referralToastMessage;
        String? referralToastCode;
        var agencyReferralAppliedOnLogin = false;

        final ra = responseData['referralApply'];
        if (ra is Map<String, dynamic> && ra['ok'] == false) {
          debugPrint(
            '⚠️ [AUTH] Referral code not applied at signup: ${ra['code']}',
          );
        }
        if (pendingReferralForLogin != null) {
          if (ra is Map<String, dynamic>) {
            if (ra['ok'] == true) {
              _pendingReferralCode = null;
              unawaited(_persistPendingReferralCode());
            } else {
              final code = ra['code'] as String?;
              referralToastCode = code;
              final serverMessage = ra['message'] as String?;
              referralToastMessage =
                  (serverMessage != null && serverMessage.trim().isNotEmpty)
                  ? serverMessage.trim()
                  : ReferralApplyMessages.forServerCode(code);
              final agencyRetryCodes = {
                'NOT_ELIGIBLE_ROLE',
                'WINDOW_EXPIRED',
                'PURCHASE_ALREADY',
              };
              if (code != null && agencyRetryCodes.contains(code)) {
                try {
                  await ReferralService().applyAgencyHostReferral(
                    pendingReferralForLogin,
                  );
                  _pendingReferralCode = null;
                  unawaited(_persistPendingReferralCode());
                  referralToastMessage = null;
                  referralToastCode = null;
                  agencyReferralAppliedOnLogin = true;
                } on ApplyReferralException catch (agencyErr) {
                  referralToastCode = agencyErr.errorCode;
                  referralToastMessage = agencyErr.message;
                  final retain = agencyErr.errorCode == 'INVALID_FORMAT' ||
                      agencyErr.errorCode == 'NOT_FOUND' ||
                      agencyErr.errorCode == 'AGENT_DISABLED' ||
                      agencyErr.errorCode == 'CREATOR_CANNOT_REFER';
                  _pendingReferralCode = retain ? pendingReferralForLogin : null;
                  unawaited(_persistPendingReferralCode());
                } catch (_) {
                  _pendingReferralCode = null;
                  unawaited(_persistPendingReferralCode());
                }
              } else if (code == 'INVALID_FORMAT' ||
                  code == 'NOT_FOUND' ||
                  code == 'AGENT_DISABLED' ||
                  code == 'CREATOR_CANNOT_REFER') {
                _pendingReferralCode = pendingReferralForLogin;
                unawaited(_persistPendingReferralCode());
              } else {
                _pendingReferralCode = null;
                unawaited(_persistPendingReferralCode());
              }
            }
          } else {
            _pendingReferralCode = null;
            unawaited(_persistPendingReferralCode());
          }
        }
        referralDispositionFinalized = true;

        // Check if this is a creator login (flat structure) or regular user (nested structure)
        final createdNow = responseData['createdNow'] == true;
        UserModel user;
        if (responseData.containsKey('user')) {
          // Regular user login - nested structure
          final userData = responseData['user'] as Map<String, dynamic>;
          user = UserModel.fromJson(userData).copyWith(
            hasAgencyAssignment: responseData['hasAgencyAssignment'] == true,
          );
          debugPrint('👤 [AUTH] Regular user login detected');
        } else {
          // Creator login - flat structure with creator details
          // Map creator fields to UserModel
          final creatorData = responseData;
          final onboardingData =
              creatorData['onboarding'] as Map<String, dynamic>?;
          user = UserModel(
            id: creatorData['id'] as String,
            email: creatorData['email'] as String?,
            phone: creatorData['phone'] as String?,
            gender: creatorData['gender'] as String?,
            username: creatorData['username'] as String?,
            avatarAsset: AvatarAssetView.fromJson(
              creatorData['avatarAsset'] as Map<String, dynamic>?,
            ),
            categories: creatorData['categories'] != null
                ? List<String>.from(creatorData['categories'] as List)
                : null,
            usernameChangeCount:
                creatorData['usernameChangeCount'] as int? ?? 0,
            coins: creatorData['coins'] as int? ?? 0,
            introFreeCallCredits:
                (creatorData['introFreeCallCredits'] as num?)?.toInt() ?? 0,
            welcomeFreeCallEligible:
                creatorData['welcomeFreeCallEligible'] == true,
            role: creatorData['role'] as String? ?? 'creator',
            creatorApplicationPending:
                creatorData['creatorApplicationPending'] == true,
            creatorApplicationRejected:
                creatorData['creatorApplicationRejected'] == true,
            creatorApplicationRejectionReason:
                creatorData['creatorApplicationRejectionReason'] as String?,
            name: creatorData['name'] as String?, // Creator name
            about: creatorData['about'] as String?, // Creator about
            age: creatorData['age'] != null
                ? creatorData['age'] as int?
                : null, // Creator age
            referralCode: creatorData['referralCode'] as String?,
            createdAt: creatorData['createdAt'] != null
                ? DateTime.parse(creatorData['createdAt'] as String)
                : null,
            updatedAt: creatorData['updatedAt'] != null
                ? DateTime.parse(creatorData['updatedAt'] as String)
                : null,
            profileRevision:
                (creatorData['profileRevision'] as num?)?.toInt() ?? 0,
            onboardingStage:
                onboardingData?['stage'] as String?,
            onboardingWelcomeSeenAt: onboardingData?['welcomeSeenAt'] != null
                ? DateTime.tryParse(onboardingData!['welcomeSeenAt'] as String)
                : null,
            onboardingBonusSeenAt: onboardingData?['bonusSeenAt'] != null
                ? DateTime.tryParse(onboardingData!['bonusSeenAt'] as String)
                : null,
            onboardingPermissionSeenAt:
                onboardingData?['permissionSeenAt'] != null
                ? DateTime.tryParse(onboardingData!['permissionSeenAt'] as String)
                : null,
            onboardingCompletedAt: onboardingData?['completedAt'] != null
                ? DateTime.tryParse(onboardingData!['completedAt'] as String)
                : null,
            onboardingPermissionsIntroAcceptedAt:
                onboardingData?['permissionsIntroAcceptedAt'] != null
                ? DateTime.tryParse(
                    onboardingData!['permissionsIntroAcceptedAt'] as String,
                  )
                : null,
            onboardingPermissionsLastCheckedAt:
                onboardingData?['permissionsLastCheckedAt'] != null
                ? DateTime.tryParse(
                    onboardingData!['permissionsLastCheckedAt'] as String,
                  )
                : null,
            onboardingCameraMicStatus:
                onboardingData?['cameraMicStatus'] as String? ?? 'unknown',
            onboardingNotificationStatus:
                onboardingData?['notificationStatus'] as String? ?? 'unknown',
            hasAgencyAssignment: creatorData['hasAgencyAssignment'] == true,
          );
          debugPrint('🎭 [AUTH] Creator login detected');
          debugPrint('   👤 Creator Name: ${creatorData['name']}');
          debugPrint('   💰 Price: ${creatorData['price']}');
        }

        debugPrint('───────────────────────────────────────────────────────');
        debugPrint('✅ [AUTH] Backend sync successful');
        debugPrint('───────────────────────────────────────────────────────');
        debugPrint('   🆔 User ID: ${user.id}');
        debugPrint('   📧 Email: ${user.email ?? "N/A"}');
        debugPrint('   📱 Phone: ${user.phone ?? "N/A"}');
        debugPrint('   🪙 Coins: ${user.coins}');
        debugPrint('   👤 Role: ${user.role ?? "N/A"}');
        debugPrint('   📅 Created: ${user.createdAt}');
        debugPrint('   🔄 Updated: ${user.updatedAt}');

        await prefs.setString(AppConstants.keyUserId, user.id);
        if (user.email != null) {
          await prefs.setString(AppConstants.keyUserEmail, user.email!);
        }
        if (user.phone != null) {
          await prefs.setString(AppConstants.keyUserPhone, user.phone!);
        }
        await prefs.setInt(AppConstants.keyUserCoins, user.coins);
        debugPrint('💾 [AUTH] User data saved to local storage');
        debugPrint('   ✅ User ID saved');
        debugPrint('   ✅ Email saved: ${user.email != null}');
        debugPrint('   ✅ Phone saved: ${user.phone != null}');
        debugPrint('   ✅ Coins saved: ${user.coins}');

        // 🔥 FIX: Mark sync as successful
        _lastSyncedUid = firebaseUser.uid;

        state = state.copyWith(
          firebaseUser: firebaseUser,
          user: user,
          isLoading: false,
          createdNow: createdNow,
          showWelcomeBackDialog: showWelcomeBackDialog,
        );
        debugPrint('✅ [AUTH] User authenticated and synced successfully');
        debugPrint('   🎉 Ready for app usage');

        if (agencyReferralAppliedOnLogin) {
          unawaited(refreshUser());
        }

        final rtm = referralToastMessage;
        final rtc = referralToastCode;
        if (rtm != null) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            final ctx = appRouter.routerDelegate.navigatorKey.currentContext;
            if (ctx != null && ctx.mounted) {
              const infoCodes = {'ALREADY_REFERRED', 'SELF'};
              if (rtc != null && infoCodes.contains(rtc)) {
                AppToast.showInfo(
                  ctx,
                  rtm,
                  duration: const Duration(seconds: 5),
                );
              } else {
                AppToast.showError(
                  ctx,
                  rtm,
                  duration: const Duration(seconds: 5),
                );
              }
            }
          });
        }

        // Connect to Stream Chat
        try {
          debugPrint('🔌 [AUTH] Connecting to Stream Chat...');
          final chatService = ChatService();
          await chatService.getChatToken();

          // Get Stream Chat notifier from provider (we'll need to pass ref)
          // For now, we'll handle this in a separate widget that watches auth state
          debugPrint('✅ [AUTH] Stream Chat token received');
        } catch (e) {
          final readable = UserMessageMapper.userMessageFor(
            e,
            fallback: 'Chat is temporarily unavailable. Please retry shortly.',
          );
          debugPrint('⚠️  [AUTH] Failed to connect to Stream Chat: $readable');
          // Don't block login if Stream Chat fails
        }
      } else {
        debugPrint('───────────────────────────────────────────────────────');
        debugPrint('❌ [AUTH] Backend sync failed');
        debugPrint('───────────────────────────────────────────────────────');
        debugPrint('   🔢 Status Code: ${response.statusCode}');
        debugPrint('   📦 Response Data: ${response.data}');
        debugPrint('   📋 Response Headers: ${response.headers}');
        debugPrint('   💡 Check backend logs for more details');

        String errorMsg =
            'Failed to sync user: Server returned status ${response.statusCode}';
        if (response.data != null) {
          try {
            final errorData = response.data as Map<String, dynamic>?;
            if (errorData != null && errorData.containsKey('error')) {
              errorMsg = '${errorData['error']}';
            }
          } catch (_) {
            // Ignore parsing errors
          }
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('❌ [AUTH] Backend sync error');
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('   Error: $e');
      debugPrint('   Type: ${e.runtimeType}');
      if (e is DioException) {
        debugPrint('   Dio Error Type: ${e.type}');
        debugPrint('   Dio Error Message: ${e.message}');
        if (e.response != null) {
          debugPrint('   Response Status: ${e.response?.statusCode}');
          debugPrint('   Response Data: ${e.response?.data}');
        }
      }

      if (kDebugMode && e is DioException) {
        debugPrint(
          '   Dev hints: baseUrl=${AppConstants.baseUrl} health=${AppConstants.healthCheckUrl}',
        );
      }

      final errorMessage = UserMessageMapper.userMessageFor(
        e,
        fallback:
            'Failed to sync with server. Please check your connection and try again.',
      );

      // 🔥 FIX: Preserve firebaseUser in error state so retry mechanism works.
      state = state.copyWith(
        firebaseUser: firebaseUser,
        isLoading: false,
        error: errorMessage,
        createdNow: false,
      );
      debugPrint('   💾 Error state updated with message: $errorMessage');
      if (pendingReferralForLogin != null && !referralDispositionFinalized) {
        _pendingReferralCode = pendingReferralForLogin;
      }
    } finally {
      // 🔥 FIX: Always reset sync guard
      _isSyncingToBackend = false;
    }
  }

  void clearWelcomeBackDialogFlag() {
    if (state.showWelcomeBackDialog == false) return;
    state = state.copyWith(showWelcomeBackDialog: false);
  }

  Future<void> _persistPendingReferralCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_pendingReferralCode != null && _pendingReferralCode!.isNotEmpty) {
        await prefs.setString(
          AppConstants.keyPendingReferralCode,
          _pendingReferralCode!,
        );
      } else {
        await prefs.remove(AppConstants.keyPendingReferralCode);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [AUTH] Persist pending referral failed: $e');
      }
    }
  }

  Future<void> _hydratePendingReferralFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(AppConstants.keyPendingReferralCode);
      if (s != null && s.isNotEmpty && ReferralCodeFormat.isValid(s)) {
        _pendingReferralCode = s.trim().toUpperCase();
        if (kDebugMode) {
          debugPrint('🎫 [AUTH] Restored pending referral from storage');
        }
        return;
      }

      final fromInstall = await InstallReferrerService.tryConsumeReferralCode();
      if (fromInstall != null && ReferralCodeFormat.isValid(fromInstall)) {
        _pendingReferralCode = fromInstall;
        await prefs.setString(AppConstants.keyPendingReferralCode, fromInstall);
        if (kDebugMode) {
          debugPrint('🎫 [AUTH] Pending referral from Play Install Referrer');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [AUTH] Hydrate pending referral failed: $e');
      }
    } finally {
      _completeReferralHydration();
    }
  }

  /// Set pending referral code to send on the next [POST /auth/login] sync.
  Future<void> setPendingReferralCode(String? code) async {
    _pendingReferralCode = code?.trim().isNotEmpty == true
        ? code!.trim().toUpperCase()
        : null;
    await _persistPendingReferralCode();
  }

  /// Staging value for login UI (restored from prefs or deep link).
  String? peekPendingReferralCode() => _pendingReferralCode;

  /// Sign in with Google (primary auth method)
  Future<void> signInWithGoogle() async {
    try {
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('🔐 [GOOGLE AUTH] Starting Google Sign-In');
      debugPrint('═══════════════════════════════════════════════════════');

      if (_auth == null) {
        debugPrint('❌ [GOOGLE AUTH] Firebase not initialized');
        state = state.copyWith(error: 'Firebase not initialized');
        return;
      }

      if (_auth!.currentUser != null && !state.isAuthenticated) {
        debugPrint(
          '🔄 [GOOGLE AUTH] User signed in with Firebase, retrying backend sync',
        );
        state = state.copyWith(
          isLoading: true,
          error: null,
          firebaseUser: _auth!.currentUser,
        );
        _lastSyncedUid = null;
        _isSyncingToBackend = false;
        await _syncUserToBackend(_auth!.currentUser!);
        return;
      }

      if (_auth!.currentUser != null && state.isAuthenticated) {
        debugPrint('✅ [GOOGLE AUTH] Already fully authenticated');
        return;
      }

      state = state.copyWith(isLoading: true, error: null);
      // Note: _pendingReferralCode is set by login screen before calling signInWithGoogle

      if (AppConstants.googleWebClientId.isEmpty && kDebugMode) {
        debugPrint(
          '⚠️  [GOOGLE AUTH] GOOGLE_WEB_CLIENT_ID is empty — idToken may be null; set in .env',
        );
      }

      GoogleSignInAccount? googleUser;
      try {
        googleUser = await AppGoogleSignIn.instance.signIn();
      } on PlatformException catch (e) {
        debugPrint('❌ [GOOGLE AUTH] PlatformException: ${e.code} ${e.message}');
        state = state.copyWith(
          isLoading: false,
          error: _googleSignInPlatformMessage(e),
        );
        return;
      }

      if (googleUser == null) {
        debugPrint('⏭️ [GOOGLE AUTH] User canceled sign-in');
        state = state.copyWith(isLoading: false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        debugPrint('❌ [GOOGLE AUTH] Missing idToken from GoogleSignIn');
        state = state.copyWith(
          isLoading: false,
          error: kDebugMode
              ? (AppConstants.googleWebClientId.isEmpty
                    ? 'Google: set GOOGLE_WEB_CLIENT_ID in .env (Web client) and rebuild.'
                    : 'Google: add release SHA-1 in Firebase and Web client ID in .env, rebuild.')
              : 'Google sign-in isn\'t available on this build. Please try again later.',
        );
        return;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: idToken,
      );

      await _auth!.signInWithCredential(credential);
      debugPrint('✅ [GOOGLE AUTH] Sign-in successful');
      state = state.copyWith(isLoading: false);
      // Auth state listener will trigger _syncUserToBackend
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '❌ [GOOGLE AUTH] FirebaseAuthException: ${e.code} ${e.message}',
      );
      state = state.copyWith(isLoading: false, error: _firebaseAuthMessage(e));
    } catch (e) {
      debugPrint('❌ [GOOGLE AUTH] Error: $e');
      state = state.copyWith(
        isLoading: false,
        error: UserMessageMapper.userMessageFor(
          e,
          fallback: 'Sign-in failed. Please try again.',
        ),
      );
    }
  }

  String _googleSignInPlatformMessage(PlatformException e) {
    final code = e.code.toLowerCase();
    if (code.contains('network') || code.contains('connection')) {
      return 'Network error during Google Sign-In. Check your connection and try again.';
    }
    if (code == 'sign_in_failed' || code.contains('sign_in')) {
      return kDebugMode
          ? 'Google Sign-In failed (${e.message ?? e.code}). Check Firebase OAuth clients and SHA certificates.'
          : 'Google Sign-In failed. Please try again or use phone sign-in.';
    }
    return UserMessageMapper.fromString(
      e.message ?? '',
      fallback: 'Google Sign-In failed. Please try again.',
    );
  }

  String _firebaseAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
        return 'Your Google session is invalid or expired. Please try signing in again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email using a different sign-in method.';
      default:
        return UserMessageMapper.fromString(
          e.message ?? '',
          fallback: 'Authentication failed. Please try again.',
        );
    }
  }

  /// Phone number login - sends OTP via Firebase
  Future<PhoneAuthStartResult> signInWithPhone(String phoneNumber) async {
    return _signInWithPhoneImpl(phoneNumber);
  }

  /// OTP verification - completes phone sign-in after code is sent
  Future<void> verifyOtp(String verificationId, String otp) async {
    await _verifyOtpImpl(verificationId, otp);
  }

  Future<int?> _getServerRetryAfterSeconds(String phoneNumber) async {
    try {
      await _apiClient.post(
        '/auth/phone-precheck',
        data: {'phoneNumber': phoneNumber},
      );
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 429 && data is Map<String, dynamic>) {
        final retryAfter = data['retry_after'];
        if (retryAfter is num && retryAfter > 0) {
          return retryAfter.toInt();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<PhoneAuthStartResult> _signInWithPhoneImpl(String phoneNumber) async {
    try {
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('📱 [PHONE AUTH] Starting phone number authentication');
      debugPrint('═══════════════════════════════════════════════════════');
      final normalized = _normalizePhoneE164(phoneNumber);
      if (normalized == null) {
        const err =
            'Enter a valid number with country code (e.g. +1 555 000 0000).';
        state = state.copyWith(isLoading: false, error: err);
        return const PhoneAuthStartResult(
          success: false,
          status: PhoneAuthStartStatus.failed,
          error: err,
        );
      }
      phoneNumber = normalized;
      debugPrint('   📞 Phone number: $phoneNumber');
      debugPrint('   ⏰ Timestamp: ${DateTime.now().toIso8601String()}');

      if (_auth == null) {
        debugPrint('❌ [PHONE AUTH] Firebase not initialized');
        state = state.copyWith(error: 'Firebase not initialized');
        return const PhoneAuthStartResult(
          success: false,
          status: PhoneAuthStartStatus.failed,
          error: 'Firebase not initialized',
        );
      }

      // 🔥 GUARD: Already signed in — don't call verifyPhoneNumber again
      // BUT: If the app state isn't authenticated (e.g. backend sync failed
      //       on a previous attempt), retry the sync instead of returning silently.
      if (_auth!.currentUser != null) {
        debugPrint('⏭️ [PHONE AUTH] User already signed in with Firebase');
        debugPrint('   🆔 UID: ${_auth!.currentUser!.uid}');

        if (!state.isAuthenticated) {
          debugPrint(
            '🔄 [PHONE AUTH] App state NOT authenticated — retrying backend sync',
          );
          // Clear previous error so UI shows loading instead of stale error
          state = state.copyWith(
            isLoading: true,
            error: null,
            firebaseUser: _auth!.currentUser,
          );
          _lastSyncedUid = null; // Reset so sync is allowed
          _isSyncingToBackend = false; // Reset guard so sync proceeds
          await _syncUserToBackend(_auth!.currentUser!);
          final syncOk = state.isAuthenticated && state.error == null;
          return PhoneAuthStartResult(
            success: syncOk,
            status: PhoneAuthStartStatus.syncingBackend,
            error: syncOk ? null : state.error,
          );
        } else {
          debugPrint(
            '✅ [PHONE AUTH] Already fully authenticated — no action needed',
          );
          state = state.copyWith(isLoading: false, error: null);
          return const PhoneAuthStartResult(
            success: true,
            status: PhoneAuthStartStatus.alreadyAuthenticated,
          );
        }
      }

      final retryAfterSeconds = await _getServerRetryAfterSeconds(phoneNumber);
      if (retryAfterSeconds != null) {
        final waitMinutes = (retryAfterSeconds / 60).ceil();
        final message =
            'Too many verification attempts. Please wait ${waitMinutes}m before requesting a new code.';
        state = state.copyWith(isLoading: false, error: message);
        _phoneBlockedUntil = DateTime.now().add(
          Duration(seconds: retryAfterSeconds),
        );
        return PhoneAuthStartResult(
          success: false,
          status: PhoneAuthStartStatus.blocked,
          error: message,
          retryAfterSeconds: retryAfterSeconds,
        );
      }

      // 🔥 GUARD: Verification already in progress
      if (_phoneVerificationInProgress) {
        debugPrint(
          '⏭️ [PHONE AUTH] BLOCKED - Verification already in progress',
        );
        state = state.copyWith(
          isLoading: false,
          error: 'Verification is already in progress. Please wait a moment.',
        );
        return const PhoneAuthStartResult(
          success: false,
          status: PhoneAuthStartStatus.blocked,
          error: 'Verification is already in progress. Please wait a moment.',
        );
      }

      if (_phoneBlockedUntil != null) {
        final now = DateTime.now();
        if (now.isBefore(_phoneBlockedUntil!)) {
          final remainingSeconds = _phoneBlockedUntil!
              .difference(now)
              .inSeconds;
          final remainingMinutes = (remainingSeconds / 60).ceil();
          state = state.copyWith(
            isLoading: false,
            error:
                'Too many verification attempts. Please wait ${remainingMinutes}m before requesting a new code.',
          );
          return PhoneAuthStartResult(
            success: false,
            status: PhoneAuthStartStatus.blocked,
            error:
                'Too many verification attempts. Please wait ${remainingMinutes}m before requesting a new code.',
            retryAfterSeconds: remainingSeconds,
          );
        }
        _phoneBlockedUntil = null;
      }

      // 🔥 GUARD: Rate limiting - prevent too many requests
      if (_lastVerificationAttempt != null) {
        final timeSinceLastAttempt = DateTime.now().difference(
          _lastVerificationAttempt!,
        );
        if (timeSinceLastAttempt < _verificationCooldown) {
          final remainingSeconds =
              (_verificationCooldown - timeSinceLastAttempt).inSeconds;
          debugPrint('⏭️ [PHONE AUTH] BLOCKED - Rate limit cooldown active');
          debugPrint(
            '   ⏱️  Please wait ${remainingSeconds}s before trying again',
          );
          state = state.copyWith(
            isLoading: false,
            error:
                'Please wait ${remainingSeconds}s before requesting a new code.',
          );
          return PhoneAuthStartResult(
            success: false,
            status: PhoneAuthStartStatus.blocked,
            error:
                'Please wait ${remainingSeconds}s before requesting a new code.',
            retryAfterSeconds: remainingSeconds,
          );
        }
      }

      _phoneVerificationInProgress = true;
      _lastVerificationAttempt = DateTime.now();

      final isTest = _isTestNumber(phoneNumber);
      debugPrint('   🧪 Is test number: $isTest');

      state = state.copyWith(isLoading: true, error: null);
      debugPrint(
        '🔄 [PHONE AUTH] Requesting phone verification from Firebase...',
      );
      final startResult = Completer<PhoneAuthStartResult>();

      await _auth!.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          verificationCompleted: (PhoneAuthCredential credential) async {
            debugPrint('───────────────────────────────────────────────────────');
            debugPrint('✅ [PHONE AUTH] Auto-verification completed');
            debugPrint('───────────────────────────────────────────────────────');

            // 🔥 GUARD: Prevent double sign-in
            if (_otpVerified) {
              debugPrint(
                '⏭️ [PHONE AUTH] OTP already verified, skipping auto-verify',
              );
              return;
            }
            if (_auth?.currentUser != null) {
              debugPrint(
                '⏭️ [PHONE AUTH] User already signed in, skipping auto-verify',
              );
              if (!startResult.isCompleted) {
                startResult.complete(
                  const PhoneAuthStartResult(
                    success: true,
                    status: PhoneAuthStartStatus.alreadyAuthenticated,
                  ),
                );
              }
              _phoneVerificationInProgress = false;
              return;
            }
            _otpVerified = true;

            try {
              final userCredential = await _auth!.signInWithCredential(
                credential,
              );
              debugPrint('✅ [PHONE AUTH] Auto sign-in successful');
              debugPrint('   🆔 UID: ${userCredential.user?.uid}');
              _phoneVerificationInProgress = false;
              state = state.copyWith(isLoading: false, error: null);
              if (!startResult.isCompleted) {
                startResult.complete(
                  const PhoneAuthStartResult(
                    success: true,
                    status: PhoneAuthStartStatus.autoVerified,
                  ),
                );
              }
            } catch (e) {
              debugPrint('❌ [PHONE AUTH] Auto sign-in error: $e');
              _otpVerified = false; // Reset so manual OTP can still work
              _phoneVerificationInProgress = false;
              final friendly = UserMessageMapper.userMessageFor(
                e,
                fallback: 'Auto verification failed. Enter the code manually.',
              );
              state = state.copyWith(isLoading: false, error: friendly);
              if (!startResult.isCompleted) {
                startResult.complete(
                  PhoneAuthStartResult(
                    success: false,
                    status: PhoneAuthStartStatus.failed,
                    error: friendly,
                  ),
                );
              }
            }
          },
          verificationFailed: (FirebaseAuthException e) {
          debugPrint('───────────────────────────────────────────────────────');
          debugPrint('❌ [PHONE AUTH] Verification failed');
          debugPrint('───────────────────────────────────────────────────────');
          debugPrint('   Code: ${e.code}');
          debugPrint('   Message: ${e.message ?? "No message"}');

          _phoneVerificationInProgress = false; // 🔥 Reset so user can retry

          // Map common Firebase Phone Auth errors to user-friendly messages.
          // In release, avoid leaking implementation details (SHA, Play Integrity, etc.)
          // but keep enough hints for developers in debug builds.
          String friendly;
          switch (e.code) {
            case 'invalid-phone-number':
              friendly = 'Please enter a valid phone number.';
              break;
            case 'too-many-requests':
              _phoneBlockedUntil = DateTime.now().add(_tooManyRequestsCooldown);
              friendly =
                  'Too many verification attempts. Please wait 5 minutes before trying again, or try using a different phone number.';
              break;
            case 'quota-exceeded':
              friendly =
                  'OTP service is temporarily unavailable. Please try again later.';
              break;
            case 'app-not-authorized':
            case 'invalid-app-credential':
            case 'missing-client-identifier':
            case 'captcha-check-failed':
              friendly = kDebugMode
                  ? 'Phone auth: add this APK SHA-1 in Firebase for com.matchvibe.app (upload or Play signing cert).'
                  : 'Phone sign-in isn\'t available on this build. Update the app from the Play Store or contact support@matchvibe.com.';
              break;
            default:
              friendly = UserMessageMapper.fromString(
                e.message ?? '',
                fallback: 'Verification failed. Please try again.',
              );
          }

          state = state.copyWith(isLoading: false, error: friendly);
          if (!startResult.isCompleted) {
            startResult.complete(
              PhoneAuthStartResult(
                success: false,
                status: PhoneAuthStartStatus.failed,
                error: friendly,
                retryAfterSeconds: e.code == 'too-many-requests' ? 300 : null,
              ),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('───────────────────────────────────────────────────────');
          debugPrint('✅ [PHONE AUTH] Verification code sent successfully');
          debugPrint('───────────────────────────────────────────────────────');
          debugPrint('   🆔 Verification ID: $verificationId');
          debugPrint('   📱 Phone: $phoneNumber');

          _otpVerified = false; // Reset for new verification round
          _phoneVerificationInProgress =
              false; // 🔥 Reset so user can navigate to OTP

          state = state.copyWith(
            isLoading: false,
            verificationId: verificationId,
            resendToken: resendToken,
            phoneNumber: phoneNumber,
            error: null,
          );
          debugPrint('   ✅ Ready for OTP input screen');
          if (!startResult.isCompleted) {
            startResult.complete(
              const PhoneAuthStartResult(
                success: true,
                status: PhoneAuthStartStatus.codeSent,
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (isTest) return; // 🔥 Ignore timeout for test numbers
          debugPrint('⏱️  [PHONE AUTH] Auto-retrieval timeout');
          debugPrint('   💡 User must enter code manually');
          // Rare: SMS path slow / flaky — `codeSent` may not have fired yet.
          // Firebase still provides [verificationId] so we can open OTP.
          if (!startResult.isCompleted && verificationId.isNotEmpty) {
            _phoneVerificationInProgress = false;
            _otpVerified = false;
            state = state.copyWith(
              isLoading: false,
              verificationId: verificationId,
              phoneNumber: phoneNumber,
              error: null,
            );
            startResult.complete(
              const PhoneAuthStartResult(
                success: true,
                status: PhoneAuthStartStatus.codeSent,
              ),
            );
          }
        },
        // 🔥 Test numbers: zero timeout disables auto-retrieval
        // Real numbers: 60s for SMS auto-read
        timeout: isTest ? Duration.zero : const Duration(seconds: 60),
      );

      debugPrint('✅ [PHONE AUTH] verifyPhoneNumber() call completed');
      return startResult.future.timeout(
        _phoneVerificationUserTimeout,
        onTimeout: () {
          _phoneVerificationInProgress = false;
          const message =
              'Verification is taking too long. Check signal or Wi-Fi and try again. '
              'If you use a VPN, turn it off for SMS.';
          state = state.copyWith(isLoading: false, error: message);
          return const PhoneAuthStartResult(
            success: false,
            status: PhoneAuthStartStatus.failed,
            error: message,
          );
        },
      );
    } catch (e) {
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('❌ [PHONE AUTH] Unexpected error');
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('   Error: $e');
      _phoneVerificationInProgress = false;
      state = state.copyWith(
        isLoading: false,
        error: UserMessageMapper.userMessageFor(
          e,
          fallback: 'Phone verification failed. Please try again.',
        ),
      );
      return PhoneAuthStartResult(
        success: false,
        status: PhoneAuthStartStatus.failed,
        error: UserMessageMapper.userMessageFor(
          e,
          fallback: 'Phone verification failed. Please try again.',
        ),
      );
    }
  }

  Future<void> _verifyOtpImpl(String verificationId, String otp) async {
    try {
      debugPrint('🔐 [OTP] Starting OTP verification...');
      debugPrint('   🆔 Verification ID: $verificationId');
      debugPrint('   🔢 OTP: $otp');

      if (_otpVerified) {
        debugPrint('⏭️ [OTP] Already verified, skipping duplicate');
        return;
      }

      if (_auth == null) {
        debugPrint('❌ [OTP] Firebase not initialized');
        state = state.copyWith(error: 'Firebase not initialized');
        return;
      }

      _otpVerified = true;
      state = state.copyWith(isLoading: true, error: null);

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      debugPrint('🔑 [OTP] Credential created, signing in...');

      UserCredential? userCredential;
      try {
        userCredential = await _auth!.signInWithCredential(credential);
      } catch (signInError) {
        final currentUser = _auth!.currentUser;
        if (currentUser != null) {
          debugPrint('⚠️  [OTP] Sign in had error but user is authenticated');
          state = state.copyWith(
            verificationId: null,
            resendToken: null,
            phoneNumber: null,
            isLoading: false,
          );
          return;
        }
        rethrow;
      }

      debugPrint('✅ [OTP] Sign in successful');

      if (userCredential.user != null) {
        state = state.copyWith(
          verificationId: null,
          resendToken: null,
          phoneNumber: null,
          isLoading: false,
        );
      }
    } catch (e) {
      final currentUser = _auth?.currentUser;
      if (currentUser != null) {
        state = state.copyWith(
          verificationId: null,
          resendToken: null,
          phoneNumber: null,
          isLoading: false,
          error: null,
        );
        return;
      }

      _otpVerified = false;
      debugPrint('❌ [OTP] Verification error: $e');
      if (e is FirebaseAuthException) {
        String errorMessage;
        switch (e.code) {
          case 'invalid-verification-code':
            errorMessage =
                'Invalid verification code. Please check and try again.';
            break;
          case 'session-expired':
            errorMessage =
                'Verification code expired. Please request a new code.';
            state = state.copyWith(
              verificationId: null,
              resendToken: null,
              phoneNumber: null,
              isLoading: false,
              error: errorMessage,
            );
            return;
          case 'invalid-verification-id':
            errorMessage =
                'Invalid verification session. Please request a new code.';
            state = state.copyWith(
              verificationId: null,
              resendToken: null,
              phoneNumber: null,
              isLoading: false,
              error: errorMessage,
            );
            return;
          default:
            errorMessage = UserMessageMapper.fromString(
              e.message ?? '',
              fallback: 'Verification failed. Please try again.',
            );
        }
        state = state.copyWith(isLoading: false, error: errorMessage);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Verification failed. Please try again.',
        );
      }
    }
  }

  Future<void> signOut() async {
    try {
      debugPrint('🚪 [AUTH] Starting sign out...');

      try {
        AvailabilitySocketService.instance.onLogout();
        debugPrint('✅ [AUTH] Availability socket disconnected');
      } catch (e) {
        debugPrint(
          '⚠️  [AUTH] Availability socket disconnect error (non-critical): $e',
        );
      }

      await AppGoogleSignIn.signOut();

      if (_auth != null) {
        final currentUser = _auth!.currentUser;
        if (currentUser != null) {
          debugPrint('   🆔 Signing out user: ${currentUser.uid}');
          debugPrint('   📧 Email: ${currentUser.email ?? "N/A"}');
        }

        await _auth!.signOut();
        debugPrint('✅ [AUTH] Firebase sign out successful');
      }

      debugPrint('🗑️  [AUTH] Clearing local storage...');
      ApiClient.clearAuthTokenMemory();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('✅ [AUTH] Local storage cleared');

      _otpVerified = false;
      _isSyncingToBackend = false;
      _lastSyncedUid = null;
      _phoneVerificationInProgress = false;
      _phoneBlockedUntil = null;

      state = AuthState();
      debugPrint('✅ [AUTH] Sign out completed');
    } catch (e) {
      debugPrint('❌ [AUTH] Sign out error: $e');
      state = state.copyWith(
        error: UserMessageMapper.userMessageFor(
          e,
          fallback: 'Couldn\'t sign out. Please try again.',
        ),
      );
    }
  }

  /// Update coins optimistically from socket events (instant update without API call)
  /// This is called when coins_updated socket event arrives
  void updateCoinsOptimistically(int newCoins) {
    final currentUser = state.user;
    if (currentUser == null) {
      debugPrint('⚠️  [AUTH] Cannot update coins - no current user');
      return;
    }

    debugPrint(
      '💰 [AUTH] Optimistically updating coins: ${currentUser.coins} → $newCoins',
    );

    // Update coins in user model without full refresh
    final updatedUser = currentUser.copyWith(coins: newCoins);
    state = state.copyWith(user: updatedUser);

    debugPrint('✅ [AUTH] Coins updated optimistically');
  }

  /// Refresh Firebase ID token and save to SharedPreferences.
  /// Call on app resume to avoid 401s from token expiration (~1hr lifetime).
  /// Returns true if token was refreshed successfully.
  Future<bool> refreshAuthToken() async {
    if (_auth == null) return false;
    final firebaseUser = _auth!.currentUser;
    if (firebaseUser == null) return false;
    try {
      final token = await firebaseUser.getIdToken(true);
      if (token == null) return false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyAuthToken, token);
      ApiClient.setAuthTokenMemory(token);
      if (kDebugMode) {
        debugPrint('🔑 [AUTH] Firebase ID token refreshed proactively');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️  [AUTH] Failed to refresh auth token: $e');
      }
      return false;
    }
  }

  /// Refresh user data from backend (gets latest coins balance, etc.)
  /// Uses /user/me endpoint for efficient refresh without full login flow
  Future<void> refreshUser() async {
    debugPrint('🔄 [AUTH] Refreshing user data from backend...');

    if (_auth == null) {
      debugPrint('❌ [AUTH] Firebase Auth not initialized');
      return;
    }

    final firebaseUser = _auth!.currentUser;
    if (firebaseUser == null) {
      debugPrint('⚠️  [AUTH] No current user to refresh');
      return;
    }

    try {
      debugPrint('   🆔 Current user: ${firebaseUser.uid}');

      // Use /user/me endpoint for efficient refresh (faster than full login)
      final response = await _apiClient.get('/user/me');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final responseData = response.data['data'] as Map<String, dynamic>;

        // Parse user data (handles both regular user and creator formats)
        UserModel user;
        if (responseData.containsKey('user')) {
          // Regular user - nested structure
          final userData = responseData['user'] as Map<String, dynamic>;
          user = UserModel.fromJson(userData).copyWith(
            hasAgencyAssignment: responseData['hasAgencyAssignment'] == true,
          );
          debugPrint('✅ [AUTH] User data refreshed (regular user)');
        } else {
          // Creator - flat structure
          final onboardingData =
              responseData['onboarding'] as Map<String, dynamic>?;
          user = UserModel(
            id: responseData['id'] as String,
            email: responseData['email'] as String?,
            phone: responseData['phone'] as String?,
            gender: responseData['gender'] as String?,
            username: responseData['username'] as String?,
            avatarAsset: AvatarAssetView.fromJson(
              responseData['avatarAsset'] as Map<String, dynamic>?,
            ),
            categories: responseData['categories'] != null
                ? List<String>.from(responseData['categories'] as List)
                : null,
            usernameChangeCount:
                responseData['usernameChangeCount'] as int? ?? 0,
            coins: responseData['coins'] as int? ?? 0,
            introFreeCallCredits:
                (responseData['introFreeCallCredits'] as num?)?.toInt() ?? 0,
            welcomeFreeCallEligible:
                responseData['welcomeFreeCallEligible'] == true,
            role: responseData['role'] as String? ?? 'creator',
            creatorApplicationPending:
                responseData['creatorApplicationPending'] == true,
            creatorApplicationRejected:
                responseData['creatorApplicationRejected'] == true,
            creatorApplicationRejectionReason:
                responseData['creatorApplicationRejectionReason'] as String?,
            name: responseData['name'] as String?, // Creator name
            about: responseData['about'] as String?, // Creator about
            age: responseData['age'] != null
                ? responseData['age'] as int?
                : null, // Creator age
            referralCode: responseData['referralCode'] as String?,
            createdAt: responseData['createdAt'] != null
                ? DateTime.parse(responseData['createdAt'] as String)
                : null,
            updatedAt: responseData['updatedAt'] != null
                ? DateTime.parse(responseData['updatedAt'] as String)
                : null,
            profileRevision:
                (responseData['profileRevision'] as num?)?.toInt() ?? 0,
            onboardingStage:
                onboardingData?['stage'] as String?,
            onboardingWelcomeSeenAt: onboardingData?['welcomeSeenAt'] != null
                ? DateTime.tryParse(onboardingData!['welcomeSeenAt'] as String)
                : null,
            onboardingBonusSeenAt: onboardingData?['bonusSeenAt'] != null
                ? DateTime.tryParse(onboardingData!['bonusSeenAt'] as String)
                : null,
            onboardingPermissionSeenAt:
                onboardingData?['permissionSeenAt'] != null
                ? DateTime.tryParse(onboardingData!['permissionSeenAt'] as String)
                : null,
            onboardingCompletedAt: onboardingData?['completedAt'] != null
                ? DateTime.tryParse(onboardingData!['completedAt'] as String)
                : null,
            onboardingPermissionsIntroAcceptedAt:
                onboardingData?['permissionsIntroAcceptedAt'] != null
                ? DateTime.tryParse(
                    onboardingData!['permissionsIntroAcceptedAt'] as String,
                  )
                : null,
            onboardingPermissionsLastCheckedAt:
                onboardingData?['permissionsLastCheckedAt'] != null
                ? DateTime.tryParse(
                    onboardingData!['permissionsLastCheckedAt'] as String,
                  )
                : null,
            onboardingCameraMicStatus:
                onboardingData?['cameraMicStatus'] as String? ?? 'unknown',
            onboardingNotificationStatus:
                onboardingData?['notificationStatus'] as String? ?? 'unknown',
            hasAgencyAssignment: responseData['hasAgencyAssignment'] == true,
          );
          debugPrint('✅ [AUTH] User data refreshed (creator)');
        }

        debugPrint('   💰 Updated coins balance: ${user.coins}');

        // Update state with refreshed user data
        state = state.copyWith(user: user, isLoading: false);
        debugPrint('✅ [AUTH] User data updated in state');
      } else {
        debugPrint(
          '⚠️  [AUTH] Failed to refresh user data: ${response.data['error']}',
        );
      }
    } catch (e) {
      debugPrint('❌ [AUTH] Error refreshing user data: $e');
      // Don't update state on error - keep existing data
    }
  }

  // OTP verification - commented out (phone login disabled)
  void clearVerificationState() {
    debugPrint('🗑️  [AUTH] Clearing verification state');
    state = state.copyWith(
      verificationId: null,
      resendToken: null,
      phoneNumber: null,
      error: null,
    );
  }

  /// Clear error state
  void clearError() {
    debugPrint('🗑️  [AUTH] Clearing error state');
    state = state.copyWith(error: null);
  }

  /// Public method to retry backend sync
  /// Can be called from UI to retry after network error
  Future<void> syncUserToBackend() async {
    final firebaseUser = state.firebaseUser;
    if (firebaseUser != null) {
      debugPrint('🔄 [AUTH] Retrying backend sync...');
      await _syncUserToBackend(firebaseUser);
    } else {
      debugPrint('⚠️  [AUTH] Cannot retry sync: No Firebase user found');
      state = state.copyWith(
        error: 'No user authenticated. Please sign in again.',
      );
    }
  }

  void clearCreatedNowFlag() {
    if (!state.createdNow) return;
    state = state.copyWith(createdNow: false);
  }
}
