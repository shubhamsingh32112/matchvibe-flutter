import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../../core/constants/app_constants.dart';
import '../../../core/api/api_client.dart';
import '../../chat/services/chat_service.dart';
import '../../../core/services/availability_socket_service.dart';
import '../../../core/services/device_fingerprint_service.dart';
import '../../../core/services/install_id_service.dart';
import '../../../shared/models/user_model.dart';


final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
class AuthState {
  final User? firebaseUser;
  final UserModel? user;
  final bool isLoading;
  final String? error;

  AuthState({
    this.firebaseUser,
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => firebaseUser != null && user != null;

  AuthState copyWith({
    User? firebaseUser,
    UserModel? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      firebaseUser: firebaseUser ?? this.firebaseUser,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  FirebaseAuth? _auth;
  final ApiClient _apiClient = ApiClient();
  bool _isInitializing = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: AppConstants.googleWebClientId,
  );
  
  // Referral: optional code to apply on first signup (cleared after sync)
  String? _pendingReferralCode;

  // Guards to prevent duplicate backend syncs
  bool _isSyncingToBackend = false;
  String? _lastSyncedUid;

  AuthNotifier() : super(AuthState()) {
    _initialize();
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
        state = state.copyWith(error: 'Firebase initialization required. Please run: flutterfire configure');
      }
    } finally {
      _isInitializing = false;
      debugPrint('🏁 [AUTH] Initialization complete');
    }
  }

  Future<void> _init() async {
    if (_auth == null) return;
    
    // 🔥 CRITICAL: Disable app verification in debug mode
    // Skips Play Integrity, reCAPTCHA, cert hash checks
    // Does NOT affect production builds
    if (kDebugMode) {
      await _auth!.setSettings(appVerificationDisabledForTesting: true);
      debugPrint('🧪 [AUTH] App verification DISABLED for testing (debug only)');
    }
    
    debugPrint('🔐 [AUTH] Setting up auth state listener...');

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
          debugPrint('⏭️ [AUTH] Already syncing to backend, skipping duplicate');
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
        _isSyncingToBackend = false;
        _lastSyncedUid = null;
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
    
    try {
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('🔄 [AUTH] Starting backend sync');
      debugPrint('───────────────────────────────────────────────────────');
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
      
      const overallTimeout = Duration(seconds: 20);
      debugPrint('🎫 [AUTH] Preparing login (token + optional identities)...');

      final tokenStartTime = DateTime.now();

      final tokenFuture = firebaseUser.getIdToken();

      final fingerprintFuture = (() async {
        try {
          if (await DeviceFingerprintService.isFastLoginAllowed()) {
            final fp = await DeviceFingerprintService.getDeviceFingerprint();
            return fp.isNotEmpty ? fp : null;
          }
        } catch (_) {
          // Unsupported platform / emulator / plugin failure — omit deviceFingerprint
        }
        return null;
      })();

      final results = await Future.wait<dynamic>([
        tokenFuture,
        fingerprintFuture,
      ]).timeout(overallTimeout);

      final token = results[0] as String?;
      final deviceFingerprint = results[1] as String?;
      final tokenDuration = DateTime.now().difference(tokenStartTime);
      
      if (token == null) {
        debugPrint('❌ [AUTH] Failed to get authentication token');
        debugPrint('   ⏱️  Token request duration: ${tokenDuration.inMilliseconds}ms');
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to get authentication token',
        );
        return;
      }
      debugPrint('✅ [AUTH] Firebase ID token retrieved');
      debugPrint('   ⏱️  Token request duration: ${tokenDuration.inMilliseconds}ms');
      debugPrint('   📏 Token length: ${token.length} characters');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyAuthToken, token);
      debugPrint('💾 [AUTH] Token saved to local storage');

      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('📡 [AUTH] Sending login request to backend...');
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('   🌐 Base URL: ${AppConstants.baseUrl}');
      debugPrint('   🌐 Endpoint: /auth/login');
      debugPrint('   🌐 Full URL: ${AppConstants.baseUrl}/auth/login');
      debugPrint('   🔑 Auth token: Present (${token.length} chars)');
      debugPrint('   💡 Make sure backend is running and accessible');
      // Send all identities we know (deviceFingerprint, etc.) for bonus eligibility check
      final Map<String, dynamic> loginBody = {};
      if (deviceFingerprint != null && deviceFingerprint.isNotEmpty) {
        loginBody['deviceFingerprint'] = deviceFingerprint;
      }
      if (_pendingReferralCode != null &&
          _pendingReferralCode!.trim().length == 6) {
        loginBody['referralCode'] = _pendingReferralCode!.trim().toUpperCase();
        _pendingReferralCode = null; // Clear after use
      }
      final apiStartTime = DateTime.now();
      final response = await _apiClient
          .post('/auth/login', data: loginBody.isNotEmpty ? loginBody : null)
          .timeout(overallTimeout);
      final apiDuration = DateTime.now().difference(apiStartTime);
      debugPrint('📥 [AUTH] Backend response received');
      debugPrint('   ⏱️  API call duration: ${apiDuration.inMilliseconds}ms');
      debugPrint('   🔢 Status Code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = response.data['data'] as Map<String, dynamic>;
        
        // Check if this is a creator login (flat structure) or regular user (nested structure)
        UserModel user;
        if (responseData.containsKey('user')) {
          // Regular user login - nested structure
          final userData = responseData['user'] as Map<String, dynamic>;
          user = UserModel.fromJson(userData);
          debugPrint('👤 [AUTH] Regular user login detected');
        } else {
          // Creator login - flat structure with creator details
          // Map creator fields to UserModel
          final creatorData = responseData;
          user = UserModel(
            id: creatorData['id'] as String,
            email: creatorData['email'] as String?,
            phone: creatorData['phone'] as String?,
            gender: creatorData['gender'] as String?,
            username: creatorData['username'] as String?,
            avatar: creatorData['photo'] as String?, // Use creator photo as avatar
            categories: creatorData['categories'] != null
                ? List<String>.from(creatorData['categories'] as List)
                : null,
            usernameChangeCount: creatorData['usernameChangeCount'] as int? ?? 0,
            coins: creatorData['coins'] as int? ?? 0,
            welcomeBonusClaimed: creatorData['welcomeBonusClaimed'] as bool? ?? false,
            role: creatorData['role'] as String? ?? 'creator',
            name: creatorData['name'] as String?, // Creator name
            about: creatorData['about'] as String?, // Creator about
            age: creatorData['age'] != null ? creatorData['age'] as int? : null, // Creator age
            referralCode: creatorData['referralCode'] as String?,
            createdAt: creatorData['createdAt'] != null
                ? DateTime.parse(creatorData['createdAt'] as String)
                : null,
            updatedAt: creatorData['updatedAt'] != null
                ? DateTime.parse(creatorData['updatedAt'] as String)
                : null,
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
        );
        debugPrint('✅ [AUTH] User authenticated and synced successfully');
        debugPrint('   🎉 Ready for app usage');
        
        // Connect to Stream Chat
        unawaited(() async {
          try {
            debugPrint('🔌 [AUTH] Connecting to Stream Chat...');
            final chatService = ChatService();
            await chatService.getChatToken();
            debugPrint('✅ [AUTH] Stream Chat token received');
          } catch (e) {
            debugPrint('⚠️  [AUTH] Failed to connect to Stream Chat: $e');
          }
        }());
        
      } else {
        debugPrint('───────────────────────────────────────────────────────');
        debugPrint('❌ [AUTH] Backend sync failed');
        debugPrint('───────────────────────────────────────────────────────');
        debugPrint('   🔢 Status Code: ${response.statusCode}');
        debugPrint('   📦 Response Data: ${response.data}');
        debugPrint('   📋 Response Headers: ${response.headers}');
        debugPrint('   💡 Check backend logs for more details');
        
        String errorMsg = 'Failed to sync user: Server returned status ${response.statusCode}';
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
      
      // Create a more descriptive error message
      String errorMessage = e.toString();
      if (e is TimeoutException) {
        errorMessage = 'Login timed out. Please try again.';
      }
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionError) {
          // Check for specific connection error types
          final errorString = e.toString().toLowerCase();
          if (errorString.contains('no route to host') || 
              errorString.contains('socketexception') ||
              errorString.contains('errno: 113')) {
            // Provide detailed error message with actionable steps
            errorMessage = 'Cannot connect to backend server.\n\n'
                'Current server: ${AppConstants.baseUrl}\n\n'
                'Please check:\n'
                '1. Backend is running (check terminal)\n'
                '2. Correct IP address (test: ${AppConstants.healthCheckUrl})\n'
                '3. Phone and laptop on same Wi-Fi\n'
                '4. Mobile data disabled\n'
                '5. Firewall allows port 3000';
          } else {
            errorMessage = 'Network error, no connection please try again.';
          }
        } else if (e.type == DioExceptionType.connectionTimeout || 
                   e.type == DioExceptionType.receiveTimeout) {
          errorMessage = 'Connection timeout. Backend server may be slow or unreachable.\n\n'
              'Test: ${AppConstants.healthCheckUrl}';
        } else if (e.response != null) {
          errorMessage = 'Server error: ${e.response?.statusCode} - ${e.response?.statusMessage ?? "Unknown error"}';
        } else {
          errorMessage = 'Network error, no connection please try again.';
        }
      } else if (e.toString().toLowerCase().contains('backend server is not reachable')) {
        // This is from our connectivity test
        errorMessage = e.toString();
      } else if (e.toString().toLowerCase().contains('socket') || 
                 e.toString().toLowerCase().contains('connection') ||
                 e.toString().toLowerCase().contains('network')) {
        errorMessage = 'Network error, no connection please try again.';
      }
      
      // 🔥 FIX: Preserve firebaseUser in error state so retry mechanism works.
      state = state.copyWith(
        firebaseUser: firebaseUser,
        isLoading: false,
        error: errorMessage,
      );
      debugPrint('   💾 Error state updated with message: $errorMessage');
    } finally {
      // 🔥 FIX: Always reset sync guard
      _isSyncingToBackend = false;
    }
  }

  /// Set pending referral code to apply on next signup (login/fast-login).
  void setPendingReferralCode(String? code) {
    _pendingReferralCode = code?.trim().isNotEmpty == true ? code!.trim().toUpperCase() : null;
  }

  /// Sign in with Google. Uses Firebase Auth; auth state listener triggers _syncUserToBackend.
  /// [referralCode] optional 6-char code to apply for new users (via _pendingReferralCode).
  Future<void> signInWithGoogle({String? referralCode}) async {
    try {
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('🔐 [GOOGLE] Starting Google Sign-In');
      debugPrint('═══════════════════════════════════════════════════════');

      if (_auth == null) {
        debugPrint('❌ [GOOGLE] Firebase not initialized');
        state = state.copyWith(error: 'Firebase not initialized');
        return;
      }

      if (referralCode != null && referralCode.trim().length == 6) {
        setPendingReferralCode(referralCode.trim());
      }

      state = state.copyWith(isLoading: true, error: null);

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('⏭️ [GOOGLE] User cancelled sign-in');
        state = state.copyWith(isLoading: false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      if (credential.idToken == null) {
        debugPrint('❌ [GOOGLE] No ID token from Google');
        state = state.copyWith(isLoading: false, error: 'Google sign-in failed: no ID token');
        return;
      }

      await _auth!.signInWithCredential(credential);
      debugPrint('✅ [GOOGLE] Sign-in with credential successful');
      state = state.copyWith(isLoading: false);
      // Auth state listener will trigger _syncUserToBackend
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [GOOGLE] Firebase Auth error: $e');
      final message = e.code == 'account-exists-with-different-credential'
          ? 'This email is already used with another sign-in method.'
          : (e.message ?? 'Google sign-in failed. Please try again.');
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      debugPrint('❌ [GOOGLE] Error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Sign in with Fast Login (device-based; no Google account).
  /// Backend returns a Firebase custom token; we sign in with it so the same
  /// Firebase UID identity model applies (Stream, sockets, calls unchanged).
  /// [referralCode] optional 6-char code to apply for new users.
  Future<void> signInWithFastLogin({String? referralCode}) async {
    try {
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('⚡ [FAST LOGIN] Starting Fast Login');
      debugPrint('═══════════════════════════════════════════════════════');

      if (_auth == null) {
        debugPrint('❌ [FAST LOGIN] Firebase not initialized');
        state = state.copyWith(error: 'Firebase not initialized');
        return;
      }

      final allowed = await DeviceFingerprintService.isFastLoginAllowed();
      if (!allowed) {
        debugPrint('❌ [FAST LOGIN] Emulator detected - Fast Login disabled');
        state = state.copyWith(
          error: 'Fast Login requires a real device. Please run the app on a physical device.',
        );
        return;
      }

      state = state.copyWith(isLoading: true, error: null);

      final deviceFingerprint = await DeviceFingerprintService.getDeviceFingerprint();
      final installId = await InstallIdService.getInstallId();

      final body = <String, dynamic>{
        'deviceFingerprint': deviceFingerprint,
        'installId': installId,
      };
      final refCode = referralCode ?? _pendingReferralCode;
      if (refCode != null && refCode.trim().length == 6) {
        body['referralCode'] = refCode.trim().toUpperCase();
      }

      // Call fast-login without auth token (unauthenticated endpoint)
      final dio = Dio(
        BaseOptions(
          baseUrl: AppConstants.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          validateStatus: (status) => status != null && status >= 200 && status < 300,
        ),
      );
      final response = await dio.post(
        '/auth/fast-login',
        data: body,
      );

      final data = response.data;
      if (data is! Map<String, dynamic> || data['success'] != true) {
        final msg = (data is Map && data['error'] != null) ? data['error'].toString() : 'Fast login failed';
        state = state.copyWith(isLoading: false, error: msg);
        return;
      }

      final inner = data['data'];
      final token = inner is Map ? inner['firebaseCustomToken'] as String? : null;
      if (token == null || token.isEmpty) {
        state = state.copyWith(isLoading: false, error: 'Invalid response from server');
        return;
      }

      await _auth!.signInWithCustomToken(token);
      debugPrint('✅ [FAST LOGIN] Sign-in with custom token successful');
      state = state.copyWith(isLoading: false);
      // Auth state listener will trigger _syncUserToBackend
    } on DioException catch (e) {
      debugPrint('❌ [FAST LOGIN] Dio error: $e');
      final message = e.response?.data is Map && (e.response!.data as Map)['error'] != null
          ? (e.response!.data as Map)['error'].toString()
          : (e.message ?? 'Network error. Please try again.');
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      debugPrint('❌ [FAST LOGIN] Error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    try {
      debugPrint('🚪 [AUTH] Starting sign out...');

      try {
        AvailabilitySocketService.instance.onLogout();
        debugPrint('✅ [AUTH] Availability socket disconnected');
      } catch (e) {
        debugPrint('⚠️  [AUTH] Availability socket disconnect error (non-critical): $e');
      }

      if (_auth != null) {
        final currentUser = _auth!.currentUser;
        if (currentUser != null) {
          debugPrint('   🆔 Signing out user: ${currentUser.uid}');
          debugPrint('   📧 Email: ${currentUser.email ?? "N/A"}');
        }

        await _auth!.signOut();
        debugPrint('✅ [AUTH] Firebase sign out successful');
      }

      try {
        await _googleSignIn.signOut();
        debugPrint('✅ [AUTH] Google Sign-In sign out successful');
      } catch (e) {
        debugPrint('⚠️  [AUTH] Google sign out (non-critical): $e');
      }

      debugPrint('🗑️  [AUTH] Clearing local storage...');
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('✅ [AUTH] Local storage cleared');

      _isSyncingToBackend = false;
      _lastSyncedUid = null;

      state = AuthState();
      debugPrint('✅ [AUTH] Sign out completed');
    } catch (e) {
      debugPrint('❌ [AUTH] Sign out error: $e');
      state = state.copyWith(error: e.toString());
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
    
    debugPrint('💰 [AUTH] Optimistically updating coins: ${currentUser.coins} → $newCoins');
    
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
          user = UserModel.fromJson(userData);
          debugPrint('✅ [AUTH] User data refreshed (regular user)');
        } else {
          // Creator - flat structure
          user = UserModel(
            id: responseData['id'] as String,
            email: responseData['email'] as String?,
            phone: responseData['phone'] as String?,
            gender: responseData['gender'] as String?,
            username: responseData['username'] as String?,
            avatar: responseData['photo'] as String?, // Use creator photo as avatar
            categories: responseData['categories'] != null
                ? List<String>.from(responseData['categories'] as List)
                : null,
            usernameChangeCount: responseData['usernameChangeCount'] as int? ?? 0,
            coins: responseData['coins'] as int? ?? 0,
            welcomeBonusClaimed: responseData['welcomeBonusClaimed'] as bool? ?? false,
            role: responseData['role'] as String? ?? 'creator',
            name: responseData['name'] as String?, // Creator name
            about: responseData['about'] as String?, // Creator about
            age: responseData['age'] != null ? responseData['age'] as int? : null, // Creator age
            referralCode: responseData['referralCode'] as String?,
            createdAt: responseData['createdAt'] != null
                ? DateTime.parse(responseData['createdAt'] as String)
                : null,
            updatedAt: responseData['updatedAt'] != null
                ? DateTime.parse(responseData['updatedAt'] as String)
                : null,
          );
          debugPrint('✅ [AUTH] User data refreshed (creator)');
        }
        
        debugPrint('   💰 Updated coins balance: ${user.coins}');
        
        // Update state with refreshed user data
        state = state.copyWith(user: user, isLoading: false);
        debugPrint('✅ [AUTH] User data updated in state');
      } else {
        debugPrint('⚠️  [AUTH] Failed to refresh user data: ${response.data['error']}');
      }
    } catch (e) {
      debugPrint('❌ [AUTH] Error refreshing user data: $e');
      // Don't update state on error - keep existing data
    }
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
}
