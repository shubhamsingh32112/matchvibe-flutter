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
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _isInitializing = false;
  
  // 🔥 FIX: Guards to prevent duplicate operations
  bool _otpVerified = false;  // Prevents multiple OTP verify attempts
  bool _isSyncingToBackend = false;  // Prevents duplicate backend syncs
  String? _lastSyncedUid;  // Tracks which UID was last synced
  bool _phoneVerificationInProgress = false;  // Prevents duplicate verifyPhoneNumber calls
  
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
          .where((p) => p.providerId == 'google.com')
          .isNotEmpty
          ? 'GOOGLE'
          : firebaseUser.providerData
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
      
      state = state.copyWith(isLoading: true, error: null);
      
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
            username: creatorData['name'] as String?, // Use creator name as username
            avatar: creatorData['photo'] as String?, // Use creator photo as avatar
            categories: creatorData['categories'] != null
                ? List<String>.from(creatorData['categories'] as List)
                : null,
            usernameChangeCount: creatorData['usernameChangeCount'] as int? ?? 0,
            coins: creatorData['coins'] as int? ?? 0,
            role: creatorData['role'] as String? ?? 'creator',
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
      
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
      debugPrint('   💾 Error state updated with message: $errorMessage');
    } finally {
      // 🔥 FIX: Always reset sync guard
      _isSyncingToBackend = false;
    }
  }

  Future<void> signInWithPhone(String phoneNumber) async {
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
      if (_auth!.currentUser != null) {
        debugPrint('⏭️ [PHONE AUTH] BLOCKED - User already signed in');
        debugPrint('   🆔 UID: ${_auth!.currentUser!.uid}');
        return;
      }
      
      // 🔥 GUARD: Verification already in progress
      if (_phoneVerificationInProgress) {
        debugPrint('⏭️ [PHONE AUTH] BLOCKED - Verification already in progress');
        return;
      }
      _phoneVerificationInProgress = true;
      
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
          
          state = state.copyWith(
            isLoading: false,
            error: e.message ?? 'Verification failed',
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
      debugPrint('   Type: ${e.runtimeType}');
      debugPrint('   Stack trace:');
      debugPrint('   ${StackTrace.current}');
      
      if (e is FirebaseAuthException) {
        debugPrint('   Firebase Error Code: ${e.code}');
        debugPrint('   Firebase Error Message: ${e.message}');
      }
      
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('🔵 [GOOGLE AUTH] Starting Google sign in');
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('   ⏰ Timestamp: ${DateTime.now().toIso8601String()}');
      
      if (_auth == null) {
        debugPrint('❌ [GOOGLE AUTH] Firebase not initialized');
        debugPrint('   💡 Please ensure Firebase is properly configured');
        state = state.copyWith(error: 'Firebase not initialized');
        return;
      }
      
      debugPrint('✅ [GOOGLE AUTH] Firebase Auth instance available');
      debugPrint('✅ [GOOGLE AUTH] GoogleSignIn instance available');
      state = state.copyWith(isLoading: true, error: null);
      
      // Check if user is already signed in to Google
      debugPrint('🔄 [GOOGLE AUTH] Checking for existing Google sign in...');
      final currentGoogleUser = await _googleSignIn.signInSilently();
      if (currentGoogleUser != null) {
        debugPrint('   ℹ️  Found existing Google sign in');
        debugPrint('   📧 Email: ${currentGoogleUser.email}');
      } else {
        debugPrint('   ℹ️  No existing Google sign in found');
      }
      
      // Trigger the Google Sign In flow
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('🔄 [GOOGLE AUTH] Requesting Google sign in...');
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('   📱 Opening Google sign-in dialog...');
      final startTime = DateTime.now();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      final dialogDuration = DateTime.now().difference(startTime);
      debugPrint('   ⏱️  Dialog duration: ${dialogDuration.inMilliseconds}ms');
      
      if (googleUser == null) {
        // User canceled the sign-in
        debugPrint('───────────────────────────────────────────────────────');
        debugPrint('⚠️  [GOOGLE AUTH] User canceled Google sign in');
        debugPrint('───────────────────────────────────────────────────────');
        debugPrint('   💡 User closed the sign-in dialog');
        debugPrint('   💡 No authentication performed');
        state = state.copyWith(isLoading: false);
        return;
      }
      
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('✅ [GOOGLE AUTH] Google sign in successful');
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('   📧 Email: ${googleUser.email}');
      debugPrint('   👤 Display Name: ${googleUser.displayName ?? "N/A"}');
      debugPrint('   🆔 Google ID: ${googleUser.id}');
      debugPrint('   🖼️  Photo URL: ${googleUser.photoUrl ?? "N/A"}');
      debugPrint('   🌐 Server Auth Code: ${googleUser.serverAuthCode != null ? "Present" : "Not provided"}');
      
      // Obtain the auth details from the request
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('🔄 [GOOGLE AUTH] Getting authentication tokens...');
      debugPrint('───────────────────────────────────────────────────────');
      final authStartTime = DateTime.now();
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final authDuration = DateTime.now().difference(authStartTime);
      debugPrint('   ⏱️  Token retrieval duration: ${authDuration.inMilliseconds}ms');
      debugPrint('   🔑 Access Token: ${googleAuth.accessToken != null ? "Present (${googleAuth.accessToken!.length} chars)" : "Not provided"}');
      debugPrint('   🆔 ID Token: ${googleAuth.idToken != null ? "Present (${googleAuth.idToken!.length} chars)" : "Not provided"}');
      
      // Create a new credential
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('🔑 [GOOGLE AUTH] Creating Firebase credential...');
      debugPrint('───────────────────────────────────────────────────────');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      debugPrint('   ✅ Credential created successfully');
      debugPrint('   🔐 Provider: ${credential.providerId}');
      
      // Sign in to Firebase with the Google credential
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('🔄 [GOOGLE AUTH] Signing in to Firebase...');
      debugPrint('───────────────────────────────────────────────────────');
      final firebaseStartTime = DateTime.now();
      final userCredential = await _auth!.signInWithCredential(credential);
      final firebaseDuration = DateTime.now().difference(firebaseStartTime);
      
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('✅ [GOOGLE AUTH] Firebase sign in successful');
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('   ⏱️  Firebase sign in duration: ${firebaseDuration.inMilliseconds}ms');
      debugPrint('   🆔 UID: ${userCredential.user?.uid}');
      debugPrint('   📧 Email: ${userCredential.user?.email ?? "N/A"}');
      debugPrint('   ✉️  Email verified: ${userCredential.user?.emailVerified ?? false}');
      debugPrint('   👤 Display Name: ${userCredential.user?.displayName ?? "N/A"}');
      debugPrint('   🖼️  Photo URL: ${userCredential.user?.photoURL ?? "N/A"}');
      debugPrint('   📱 Phone: ${userCredential.user?.phoneNumber ?? "N/A"}');
      debugPrint('   📅 Created: ${userCredential.user?.metadata.creationTime}');
      debugPrint('   🔄 Last sign in: ${userCredential.user?.metadata.lastSignInTime}');
      
      // Safely access providerData to avoid type cast errors
      try {
        final providers = userCredential.user?.providerData
            .map((p) => p.providerId)
            .join(", ") ?? "N/A";
        debugPrint('   🔗 Providers: $providers');
      } catch (e) {
        debugPrint('   🔗 Providers: Error accessing provider data (non-critical): $e');
      }
      
      if (userCredential.user != null) {
        debugPrint('───────────────────────────────────────────────────────');
        debugPrint('✅ [GOOGLE AUTH] Firebase authentication complete');
        debugPrint('───────────────────────────────────────────────────────');
        debugPrint('   📧 User Email: ${userCredential.user?.email}');
        debugPrint('   🆔 Firebase UID: ${userCredential.user?.uid}');
        debugPrint('   ✅ Authentication: Complete');
        debugPrint('   🔄 Backend sync will be handled by auth state listener');
        debugPrint('   💡 Auth state listener will automatically sync user to backend');
        
        // Don't manually call _syncUserToBackend here - the auth state listener
        // will handle it automatically when it detects the user is signed in.
        // This prevents duplicate sync calls and race conditions.
        
        // Clear loading state - backend sync will happen via auth state listener
        state = state.copyWith(
          isLoading: false,
          error: null, // Clear any previous errors
        );
        
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint('✅ [GOOGLE AUTH] Sign-in flow complete');
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint('   🎉 User signed in successfully');
        debugPrint('   🔄 Backend sync in progress via auth state listener');
      } else {
        debugPrint('⚠️  [GOOGLE AUTH] User credential is null');
        debugPrint('   ❌ Cannot proceed');
        state = state.copyWith(
          isLoading: false,
          error: 'User credential is null',
        );
      }
    } catch (e) {
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('❌ [GOOGLE AUTH] Sign in error');
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('   Error: $e');
      debugPrint('   Type: ${e.runtimeType}');
      debugPrint('   Full error string: ${e.toString()}');
      
      // Check if user is actually authenticated despite the error
      // This handles cases where Firebase has internal errors but authentication succeeds
      final currentUser = _auth?.currentUser;
      if (currentUser != null) {
        debugPrint('───────────────────────────────────────────────────────');
        debugPrint('⚠️  [GOOGLE AUTH] Error occurred but user is authenticated');
        debugPrint('───────────────────────────────────────────────────────');
        debugPrint('   🆔 Firebase UID: ${currentUser.uid}');
        debugPrint('   📧 Email: ${currentUser.email ?? "N/A"}');
        debugPrint('   💡 This is likely a non-critical Firebase internal error');
        debugPrint('   💡 User authentication succeeded, backend sync will continue');
        debugPrint('   💡 Clearing error state to allow normal flow');
        
        // User is authenticated, so clear the error and let auth state listener handle sync
        state = state.copyWith(
          isLoading: false,
          error: null, // Clear error since user is actually authenticated
        );
        return;
      }
      
      String errorMessage = e.toString();
      
      if (e is FirebaseAuthException) {
        debugPrint('   Firebase Error Code: ${e.code}');
        debugPrint('   Firebase Error Message: ${e.message}');
        debugPrint('   Firebase Error Details: ${e.toString()}');
        errorMessage = '${e.code}: ${e.message ?? e.toString()}';
        
        // Common error codes with helpful messages
        switch (e.code) {
          case 'account-exists-with-different-credential':
            debugPrint('   💡 An account already exists with a different credential');
            debugPrint('   💡 User may need to sign in with the original method');
            break;
          case 'invalid-credential':
            debugPrint('   💡 The credential is invalid or expired');
            break;
          case 'operation-not-allowed':
            debugPrint('   💡 Google sign-in is not enabled in Firebase Console');
            debugPrint('   💡 Enable it in Authentication > Sign-in method');
            break;
          case 'user-disabled':
            debugPrint('   💡 This user account has been disabled');
            break;
          case 'user-not-found':
            debugPrint('   💡 No user record found');
            break;
          default:
            debugPrint('   💡 Check Firebase Console for more details');
        }
      } else if (e is DioException) {
        debugPrint('   DioException Type: ${e.type}');
        debugPrint('   DioException Message: ${e.message}');
        if (e.response != null) {
          debugPrint('   Response Status: ${e.response?.statusCode}');
          debugPrint('   Response Data: ${e.response?.data}');
        }
        errorMessage = e.message ?? e.toString();
      } else if (e.toString().contains('sign_in_canceled') || 
                 e.toString().contains('SignInCanceledException')) {
        debugPrint('   💡 User canceled the Google sign-in process');
        // Don't set error for user cancellation
        state = state.copyWith(isLoading: false);
        return;
      } else if (e.toString().contains('PigeonUserDetails') || 
                 e.toString().contains('type \'List<Object?>\' is not a subtype')) {
        // This is a known Firebase internal type cast error that sometimes occurs
        // even when authentication succeeds. Check if user is actually authenticated.
        debugPrint('   💡 Firebase internal type cast error detected');
        debugPrint('   💡 This is a known issue with Firebase SDK');
        debugPrint('   💡 Checking if user is actually authenticated...');
        
        if (currentUser != null) {
          debugPrint('   ✅ User is authenticated despite the error');
          debugPrint('   💡 Ignoring this non-critical error');
          state = state.copyWith(
            isLoading: false,
            error: null,
          );
          return;
        }
      } else {
        debugPrint('   Stack trace:');
        debugPrint('   ${StackTrace.current}');
      }
      
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
      debugPrint('   💾 Error state updated');
      debugPrint('   📤 Error will be displayed to user');
    }
  }

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
      
      // Sign out from Google as well
      try {
        await _googleSignIn.signOut();
        debugPrint('✅ [AUTH] Google sign out successful');
      } catch (e) {
        debugPrint('⚠️  [AUTH] Google sign out error (non-critical): $e');
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
            username: responseData['name'] as String?,
            avatar: responseData['photo'] as String?,
            categories: responseData['categories'] != null
                ? List<String>.from(responseData['categories'] as List)
                : null,
            usernameChangeCount: responseData['usernameChangeCount'] as int? ?? 0,
            coins: responseData['coins'] as int? ?? 0,
            role: responseData['role'] as String? ?? 'creator',
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
