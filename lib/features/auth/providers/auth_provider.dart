import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/availability_socket_service.dart';
import '../../../shared/models/user_model.dart';
import '../../chat/services/chat_service.dart';

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

  AuthState({
    this.firebaseUser,
    this.user,
    this.isLoading = false,
    this.error,
    this.verificationId,
    this.resendToken,
    this.phoneNumber,
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
  }) {
    return AuthState(
      firebaseUser: firebaseUser ?? this.firebaseUser,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  FirebaseAuth? _auth;
  final ApiClient _apiClient = ApiClient();
  bool _isInitializing = false;
  
  // 🔥 FIX: Guards to prevent duplicate operations
  bool _otpVerified = false;  // Prevents multiple OTP verify attempts
  bool _isSyncingToBackend = false;  // Prevents duplicate backend syncs
  String? _lastSyncedUid;  // Tracks which UID was last synced
  bool _phoneVerificationInProgress = false;  // Prevents duplicate verifyPhoneNumber calls
  DateTime? _lastVerificationAttempt;  // Track last verification request time
  static const Duration _verificationCooldown = Duration(seconds: 30);  // Minimum time between requests
  
  // 🔥 FIX: Test phone numbers (for Firebase test authentication)
  // These numbers use manual OTP flow, no SMS auto-retrieval
  static const Set<String> _testPhoneNumbers = {
    '+919999999999',
    '+911234567890',
    '+15555555555',  // Common US test number
  };
  
  /// Check if a phone number is a Firebase test number
  bool _isTestNumber(String phone) {
    return _testPhoneNumbers.contains(phone);
  }

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
        // 🔥 FIX: Reset all guards on logout
        _otpVerified = false;
        _isSyncingToBackend = false;
        _lastSyncedUid = null;
        _phoneVerificationInProgress = false;
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
      // Determine auth method for logging context
      final authMethod = firebaseUser.providerData
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
        debugPrint('   💡 Backend is not reachable at: ${AppConstants.baseUrl}');
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
          '• Test in browser: ${AppConstants.healthCheckUrl}'
        );
      }
      
      debugPrint('✅ [AUTH] Backend connectivity test passed');
      
      debugPrint('🎫 [AUTH] Requesting Firebase ID token...');
      final tokenStartTime = DateTime.now();
      final token = await firebaseUser.getIdToken();
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
      final apiStartTime = DateTime.now();
      final response = await _apiClient.post('/auth/login');
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
        try {
          debugPrint('🔌 [AUTH] Connecting to Stream Chat...');
          final chatService = ChatService();
          await chatService.getChatToken();
          
          // Get Stream Chat notifier from provider (we'll need to pass ref)
          // For now, we'll handle this in a separate widget that watches auth state
          debugPrint('✅ [AUTH] Stream Chat token received');
        } catch (e) {
          debugPrint('⚠️  [AUTH] Failed to connect to Stream Chat: $e');
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
        debugPrint('🔄 [GOOGLE AUTH] User signed in with Firebase, retrying backend sync');
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

      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('⏭️ [GOOGLE AUTH] User canceled sign-in');
        state = state.copyWith(isLoading: false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth!.signInWithCredential(credential);
      debugPrint('✅ [GOOGLE AUTH] Sign-in successful');
      state = state.copyWith(isLoading: false);
      // Auth state listener will trigger _syncUserToBackend
    } catch (e) {
      debugPrint('❌ [GOOGLE AUTH] Error: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Stub: Phone login disabled (use signInWithGoogle)
  /// Kept for backward compatibility with otp_screen.dart
  Future<void> signInWithPhone(String phoneNumber) async {
    state = state.copyWith(
      error: 'Phone login is disabled. Please use Google Sign-In.',
      isLoading: false,
    );
  }

  /// Stub: OTP verification disabled (use signInWithGoogle)
  /// Kept for backward compatibility with otp_screen.dart
  Future<void> verifyOtp(String verificationId, String otp) async {
    state = state.copyWith(
      error: 'Phone login is disabled. Please use Google Sign-In.',
      isLoading: false,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // PHONE LOGIN FULL IMPLEMENTATION (COMMENTED OUT)
  // Uncomment signInWithPhone + verifyOtp above and restore these to re-enable
  // ─────────────────────────────────────────────────────────────────
  /*
  Future<void> _signInWithPhoneImpl(String phoneNumber) async {
    try {
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('📱 [PHONE AUTH] Starting phone number authentication');
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('   📞 Phone number: $phoneNumber');
      debugPrint('   ⏰ Timestamp: ${DateTime.now().toIso8601String()}');
      
      if (_auth == null) {
        debugPrint('❌ [PHONE AUTH] Firebase not initialized');
        state = state.copyWith(error: 'Firebase not initialized');
        return;
      }
      
      // 🔥 GUARD: Already signed in — don't call verifyPhoneNumber again
      // BUT: If the app state isn't authenticated (e.g. backend sync failed
      //       on a previous attempt), retry the sync instead of returning silently.
      if (_auth!.currentUser != null) {
        debugPrint('⏭️ [PHONE AUTH] User already signed in with Firebase');
        debugPrint('   🆔 UID: ${_auth!.currentUser!.uid}');
        
        if (!state.isAuthenticated) {
          debugPrint('🔄 [PHONE AUTH] App state NOT authenticated — retrying backend sync');
          // Clear previous error so UI shows loading instead of stale error
          state = state.copyWith(
            isLoading: true,
            error: null,
            firebaseUser: _auth!.currentUser,
          );
          _lastSyncedUid = null; // Reset so sync is allowed
          _isSyncingToBackend = false; // Reset guard so sync proceeds
          await _syncUserToBackend(_auth!.currentUser!);
        } else {
          debugPrint('✅ [PHONE AUTH] Already fully authenticated — no action needed');
        }
        return;
      }
      
      // 🔥 GUARD: Verification already in progress
      if (_phoneVerificationInProgress) {
        debugPrint('⏭️ [PHONE AUTH] BLOCKED - Verification already in progress');
        return;
      }
      
      // 🔥 GUARD: Rate limiting - prevent too many requests
      if (_lastVerificationAttempt != null) {
        final timeSinceLastAttempt = DateTime.now().difference(_lastVerificationAttempt!);
        if (timeSinceLastAttempt < _verificationCooldown) {
          final remainingSeconds = (_verificationCooldown - timeSinceLastAttempt).inSeconds;
          debugPrint('⏭️ [PHONE AUTH] BLOCKED - Rate limit cooldown active');
          debugPrint('   ⏱️  Please wait ${remainingSeconds}s before trying again');
          state = state.copyWith(
            isLoading: false,
            error: 'Please wait ${remainingSeconds}s before requesting a new code.',
          );
          return;
        }
      }
      
      _phoneVerificationInProgress = true;
      _lastVerificationAttempt = DateTime.now();
      
      final isTest = _isTestNumber(phoneNumber);
      debugPrint('   🧪 Is test number: $isTest');
      
      state = state.copyWith(isLoading: true, error: null);
      debugPrint('🔄 [PHONE AUTH] Requesting phone verification from Firebase...');
      
      await _auth!.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('───────────────────────────────────────────────────────');
          debugPrint('✅ [PHONE AUTH] Auto-verification completed');
          debugPrint('───────────────────────────────────────────────────────');
          
          // 🔥 GUARD: Prevent double sign-in
          if (_otpVerified) {
            debugPrint('⏭️ [PHONE AUTH] OTP already verified, skipping auto-verify');
            return;
          }
          if (_auth?.currentUser != null) {
            debugPrint('⏭️ [PHONE AUTH] User already signed in, skipping auto-verify');
            return;
          }
          _otpVerified = true;
          
          try {
            final userCredential = await _auth!.signInWithCredential(credential);
            debugPrint('✅ [PHONE AUTH] Auto sign-in successful');
            debugPrint('   🆔 UID: ${userCredential.user?.uid}');
            _phoneVerificationInProgress = false;
          } catch (e) {
            debugPrint('❌ [PHONE AUTH] Auto sign-in error: $e');
            _otpVerified = false;  // Reset so manual OTP can still work
            _phoneVerificationInProgress = false;
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('───────────────────────────────────────────────────────');
          debugPrint('❌ [PHONE AUTH] Verification failed');
          debugPrint('───────────────────────────────────────────────────────');
          debugPrint('   Code: ${e.code}');
          debugPrint('   Message: ${e.message ?? "No message"}');
          
          _phoneVerificationInProgress = false;  // 🔥 Reset so user can retry

          // Map common Firebase Phone Auth errors to user-friendly messages.
          // In release, avoid leaking implementation details (SHA, Play Integrity, etc.)
          // but keep enough hints for developers in debug builds.
          String friendly;
          switch (e.code) {
            case 'invalid-phone-number':
              friendly = 'Please enter a valid phone number.';
              break;
            case 'too-many-requests':
              // Firebase rate limit hit - enforce longer cooldown
              _lastVerificationAttempt = DateTime.now();
              // Extend cooldown to 5 minutes for too-many-requests
              _lastVerificationAttempt = _lastVerificationAttempt!.subtract(
                const Duration(minutes: 5) - _verificationCooldown,
              );
              friendly = 'Too many verification attempts. Please wait 5 minutes before trying again, or try using a different phone number.';
              break;
            case 'quota-exceeded':
              friendly = 'OTP service is temporarily unavailable. Please try again later.';
              break;
            case 'app-not-authorized':
            case 'invalid-app-credential':
            case 'missing-client-identifier':
            case 'captcha-check-failed':
              friendly = kDebugMode
                  ? 'Phone verification blocked for this build. Add release SHA-256/SHA-1 to Firebase (Android app: com.example.zztherapy), then retry.'
                  : 'Verification is temporarily unavailable. Please try again later.';
              break;
            default:
              friendly = e.message ?? 'Verification failed. Please try again.';
          }
          
          state = state.copyWith(
            isLoading: false,
            error: friendly,
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('───────────────────────────────────────────────────────');
          debugPrint('✅ [PHONE AUTH] Verification code sent successfully');
          debugPrint('───────────────────────────────────────────────────────');
          debugPrint('   🆔 Verification ID: $verificationId');
          debugPrint('   📱 Phone: $phoneNumber');
          
          _otpVerified = false;  // Reset for new verification round
          _phoneVerificationInProgress = false;  // 🔥 Reset so user can navigate to OTP
          
          state = state.copyWith(
            isLoading: false,
            verificationId: verificationId,
            resendToken: resendToken,
            phoneNumber: phoneNumber,
            error: null,
          );
          debugPrint('   ✅ Ready for OTP input screen');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (isTest) return;  // 🔥 Ignore timeout for test numbers
          debugPrint('⏱️  [PHONE AUTH] Auto-retrieval timeout');
          debugPrint('   💡 User must enter code manually');
        },
        // 🔥 Test numbers: zero timeout disables auto-retrieval
        // Real numbers: 60s for SMS auto-read
        timeout: isTest ? Duration.zero : const Duration(seconds: 60),
      );
      
      debugPrint('✅ [PHONE AUTH] verifyPhoneNumber() call completed');
    } catch (e) {
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('❌ [PHONE AUTH] Unexpected error');
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('   Error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
  */

  Future<void> signOut() async {
    try {
      debugPrint('🚪 [AUTH] Starting sign out...');
      
      // 🔥 FIX 5: Disconnect availability socket on logout
      // This emits offline and cleans up the connection
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
      
      debugPrint('🗑️  [AUTH] Clearing local storage...');
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('✅ [AUTH] Local storage cleared');
      
      // 🔥 Reset ALL guards on sign out
      _otpVerified = false;
      _isSyncingToBackend = false;
      _lastSyncedUid = null;
      _phoneVerificationInProgress = false;
      
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


  // OTP verification - commented out (phone login disabled)
  /*
  Future<void> verifyOtp(String verificationId, String otp) async {
    try {
      debugPrint('🔐 [OTP] Starting OTP verification...');
      debugPrint('   🆔 Verification ID: $verificationId');
      debugPrint('   🔢 OTP: $otp');
      
      // 🔥 CRITICAL GUARD: Prevent double verification
      if (_otpVerified) {
        debugPrint('⏭️ [OTP] Already verified, skipping duplicate');
        return;
      }
      
      if (_auth == null) {
        debugPrint('❌ [OTP] Firebase not initialized');
        state = state.copyWith(error: 'Firebase not initialized');
        return;
      }
      
      _otpVerified = true;  // 🔥 Set BEFORE async work
      state = state.copyWith(isLoading: true, error: null);
      
      // Create credential from verification ID and OTP
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      
      debugPrint('🔑 [OTP] Credential created, signing in...');
      
      UserCredential? userCredential;
      try {
        userCredential = await _auth!.signInWithCredential(credential);
      } catch (signInError) {
        // Sometimes Firebase throws an internal error but still signs in
        // Check if user is actually signed in
        final currentUser = _auth!.currentUser;
        if (currentUser != null) {
          debugPrint('⚠️  [OTP] Sign in had error but user is authenticated');
          debugPrint('   🆔 UID: ${currentUser.uid}');
          debugPrint('   📱 Phone: ${currentUser.phoneNumber}');
          debugPrint('   ⚠️  Original error (ignored): $signInError');
          
          // Clear verification data
          state = state.copyWith(
            verificationId: null,
            resendToken: null,
            phoneNumber: null,
            isLoading: false,
          );
          
          // Auth state listener will handle backend sync
          return;
        } else {
          // Re-throw if user is not signed in
          rethrow;
        }
      }
      
      debugPrint('✅ [OTP] Sign in successful');
      debugPrint('   🆔 UID: ${userCredential.user?.uid}');
      debugPrint('   📱 Phone: ${userCredential.user?.phoneNumber}');
      
      if (userCredential.user != null) {
        // Clear verification data
        state = state.copyWith(
          verificationId: null,
          resendToken: null,
          phoneNumber: null,
          isLoading: false,
        );
        
        // Don't call _syncUserToBackend here - let the auth state listener handle it
        // This prevents duplicate calls and race conditions
      }
    } catch (e) {
      // Check if user is actually authenticated despite the error
      final currentUser = _auth?.currentUser;
      if (currentUser != null) {
        debugPrint('⚠️  [OTP] Error occurred but user is authenticated');
        debugPrint('   🆔 UID: ${currentUser.uid}');
        debugPrint('   📱 Phone: ${currentUser.phoneNumber}');
        debugPrint('   ⚠️  Error (non-critical): $e');
        
        // Clear verification data and mark as not loading
        // Auth state listener will handle backend sync
        state = state.copyWith(
          verificationId: null,
          resendToken: null,
          phoneNumber: null,
          isLoading: false,
          error: null, // Don't show error if user is authenticated
        );
        return;
      }
      
      // User is not authenticated, show the error
      _otpVerified = false;  // 🔥 Reset so user can retry
      debugPrint('❌ [OTP] Verification error');
      if (e is FirebaseAuthException) {
        debugPrint('   Code: ${e.code}');
        debugPrint('   Message: ${e.message}');
        debugPrint('   Details: ${e.toString()}');
        
        String errorMessage = e.message ?? e.toString();
        
        // Common error codes with user-friendly messages
        switch (e.code) {
          case 'invalid-verification-code':
            debugPrint('   💡 Invalid OTP code. Please check and try again.');
            errorMessage = 'Invalid verification code. Please check and try again.';
            break;
          case 'session-expired':
            debugPrint('   💡 Verification session expired. Please request a new code.');
            errorMessage = 'Verification code expired. Please request a new code.';
            // Clear verification state for expired sessions
            state = state.copyWith(
              verificationId: null,
              resendToken: null,
              phoneNumber: null,
              isLoading: false,
              error: errorMessage,
            );
            return;
          case 'invalid-verification-id':
            debugPrint('   💡 Invalid verification ID. Please request a new code.');
            errorMessage = 'Invalid verification session. Please request a new code.';
            // Clear verification state for invalid sessions
            state = state.copyWith(
              verificationId: null,
              resendToken: null,
              phoneNumber: null,
              isLoading: false,
              error: errorMessage,
            );
            return;
          default:
            errorMessage = e.message ?? 'Verification failed. Please try again.';
        }
        
        state = state.copyWith(
          isLoading: false,
          error: errorMessage,
        );
      } else {
        debugPrint('   Error: $e');
        debugPrint('   Stack trace: ${StackTrace.current}');
        
        state = state.copyWith(
          isLoading: false,
          error: 'Verification failed. Please try again.',
        );
      }
    }
  }
  */

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
}
