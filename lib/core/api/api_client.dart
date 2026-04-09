import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../constants/app_constants.dart';

class ApiClient {
  late final Dio _dio;
  static final ApiClient _instance = ApiClient._internal();
  bool _isRefreshingToken = false;

  factory ApiClient() => _instance;

  ApiClient._internal() {
    final baseUrl = AppConstants.baseUrl;
    
    if (kDebugMode) {
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('🌐 [API CLIENT] Initializing HTTP client');
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('   📍 Platform: ${_getPlatformName()}');
      debugPrint('   🔗 Base URL: $baseUrl');
      debugPrint('   ⏱️  Connect Timeout: 15 seconds');
      debugPrint('   ⏱️  Receive Timeout: 30 seconds');
      debugPrint('═══════════════════════════════════════════════════════');
    }
    
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        // Increased timeouts for network reliability
        connectTimeout: const Duration(seconds: 15), // Increased from 10
        receiveTimeout: const Duration(seconds: 30), // Increased from 10
        sendTimeout: const Duration(seconds: 15), // Added send timeout
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        // Allow following redirects
        followRedirects: true,
        maxRedirects: 5,
        // Validate status codes (200-299 are valid)
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (kDebugMode) {
            debugPrint(
              '📤 [API] ${options.method} ${options.baseUrl}${options.path}',
            );
            if (options.data != null) {
              debugPrint('   📦 Request data: ${options.data}');
            }
            if (options.queryParameters.isNotEmpty) {
              debugPrint('   🔍 Query params: ${options.queryParameters}');
            }
          }
          
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString(AppConstants.keyAuthToken);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            if (kDebugMode) {
              debugPrint('   🔑 Auth token attached (length: ${token.length})');
            }
          } else {
            if (kDebugMode) {
              debugPrint('   ⚠️  No auth token found');
            }
          }
          
          if (kDebugMode) {
            debugPrint('   📋 Headers: ${options.headers}');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint(
              '📥 [API] Response: ${response.statusCode} ${response.statusMessage}',
            );
            debugPrint('   📍 URL: ${response.requestOptions.uri}');
            if (response.data != null) {
              debugPrint('   📦 Response data: ${response.data}');
            }
          }
          return handler.next(response);
        },
        onError: (error, handler) async {
          if (kDebugMode) {
            debugPrint('═══════════════════════════════════════════════════════');
            debugPrint('❌ [API] Request failed');
            debugPrint('═══════════════════════════════════════════════════════');
            debugPrint('   📍 URL: ${error.requestOptions.uri}');
            debugPrint('   🔢 Status: ${error.response?.statusCode ?? "N/A"}');
            debugPrint('   💬 Message: ${error.message}');
            debugPrint('   🔧 Error Type: ${error.type}');
            debugPrint('   📱 Platform: ${_getPlatformName()}');
            debugPrint('   🔗 Base URL: ${AppConstants.baseUrl}');
          }
          
          if (error.response != null) {
            if (kDebugMode) {
              debugPrint('   📦 Error data: ${error.response?.data}');
              debugPrint('   📋 Response headers: ${error.response?.headers}');
            }
          }
          
          // 🔥 Firebase ID token expired: refresh and retry once
          if (error.response?.statusCode == 401 && !_isRefreshingToken) {
            final isTokenExpired = _isTokenExpiredError(error);
            if (kDebugMode && isTokenExpired) {
              debugPrint('   🔒 Token expired - attempting refresh and retry');
            }
            if (isTokenExpired) {
              _isRefreshingToken = true;
              try {
                final newToken = await _refreshFirebaseToken();
                if (newToken != null) {
                  if (kDebugMode) {
                    debugPrint('   ✅ Token refreshed, retrying request');
                  }
                  final opts = error.requestOptions;
                  opts.headers['Authorization'] = 'Bearer $newToken';
                  final response = await _dio.fetch(opts);
                  _isRefreshingToken = false;
                  return handler.resolve(response);
                }
              } catch (e) {
                if (kDebugMode) {
                  debugPrint('   ⚠️ Token refresh failed: $e');
                }
              }
              _isRefreshingToken = false;
            }
          }
          
          // Detailed error analysis
          if (error.response?.statusCode == 401) {
            if (kDebugMode) {
              debugPrint('   🔒 Unauthorized - Token may be expired or invalid');
              debugPrint('   💡 Solution: User needs to sign in again');
            }
          }
          
          if (error.type == DioExceptionType.connectionTimeout) {
            if (kDebugMode) {
              debugPrint('   ⏱️  Connection timeout - Server did not respond in time');
              debugPrint('   💡 Possible causes:');
              debugPrint('      • Backend server is not running');
              debugPrint('      • Network is slow or unstable');
              debugPrint('      • Firewall is blocking the connection');
              debugPrint('      • Wrong IP address or port');
              debugPrint('   🧪 Test: Open ${AppConstants.healthCheckUrl} in browser');
            }
          }
          
          if (error.type == DioExceptionType.receiveTimeout) {
            if (kDebugMode) {
              debugPrint('   ⏱️  Receive timeout - Server took too long to respond');
              debugPrint('   💡 Possible causes:');
              debugPrint('      • Backend is processing a heavy request');
              debugPrint('      • Network is slow');
              debugPrint('      • Backend server is overloaded');
            }
          }
          
          if (error.type == DioExceptionType.sendTimeout) {
            if (kDebugMode) {
              debugPrint('   ⏱️  Send timeout - Request took too long to send');
              debugPrint('   💡 Possible causes:');
              debugPrint('      • Network upload speed is slow');
              debugPrint('      • Request payload is too large');
              debugPrint('      • Network connection is unstable');
            }
          }
          
          if (error.type == DioExceptionType.connectionError) {
            if (kDebugMode) {
              debugPrint('   🌐 Connection error - Cannot reach server');
              debugPrint('   💡 Possible causes:');
              debugPrint('      • Backend server is not running');
              debugPrint('      • Wrong IP address (current: ${AppConstants.baseUrl})');
              debugPrint('      • Phone and laptop are on different networks');
              debugPrint('      • Mobile data is enabled (should be disabled)');
              debugPrint('      • Firewall is blocking port 3000');
              debugPrint('      • Backend is bound to localhost instead of 0.0.0.0');
              debugPrint('   🧪 Troubleshooting steps:');
              debugPrint('      1. Check backend terminal for "Server running on port 3000"');
              debugPrint('      2. Verify backend binds to 0.0.0.0 (not localhost)');
              debugPrint('      3. Test in browser: ${AppConstants.healthCheckUrl}');
              debugPrint('      4. Ensure phone and laptop are on same Wi-Fi');
              debugPrint('      5. Disable mobile data on phone');
              debugPrint('      6. Check firewall settings for port 3000');
              debugPrint('      7. Verify IP address with ipconfig/ifconfig');
            }
            
            // Platform-specific guidance
            if (Platform.isAndroid) {
              if (kDebugMode) {
                debugPrint('   📱 Android-specific:');
                debugPrint('      • For emulator: Use http://10.0.2.2:3000');
                debugPrint('      • For real device: Use http://<LAN_IP>:3000');
                debugPrint('      • Set USE_EMULATOR_IP=true for emulator');
              }
            } else if (Platform.isIOS) {
              if (kDebugMode) {
                debugPrint('   📱 iOS-specific:');
                debugPrint('      • For simulator: Use http://localhost:3000');
                debugPrint('      • For real device: Use http://<LAN_IP>:3000');
                debugPrint('      • Set USE_SIMULATOR_IP=true for simulator');
              }
            }
          }
          
          if (error.type == DioExceptionType.badResponse) {
            if (kDebugMode) {
              debugPrint('   📦 Bad response - Server returned an error');
              debugPrint('   💡 Check backend logs for more details');
            }
          }
          
          if (error.type == DioExceptionType.cancel) {
            if (kDebugMode) {
              debugPrint('   🚫 Request cancelled');
            }
          }
          
          if (error.type == DioExceptionType.unknown) {
            if (kDebugMode) {
              debugPrint('   ❓ Unknown error - Check error details above');
              if (error.error != null) {
                debugPrint('   🔍 Error details: ${error.error}');
              }
            }
          }
          
          if (kDebugMode) {
            debugPrint('═══════════════════════════════════════════════════════');
          }
          
          return handler.next(error);
        },
      ),
    );
  }

  /// Check if we should attempt token refresh for this 401
  bool _isTokenExpiredError(DioException error) {
    if (error.response?.statusCode != 401) return false;
    // Only try refresh if request had auth (Firebase token)
    final hadAuth = error.requestOptions.headers['Authorization'] != null;
    if (!hadAuth) return false;
    final data = error.response?.data;
    if (data is Map && data['error'] != null) {
      final err = data['error'].toString().toLowerCase();
      if (err.contains('id-token-expired') || err.contains('expired')) return true;
    }
    return true; // Attempt refresh for any 401 with auth header
  }

  /// Refresh Firebase ID token and save to SharedPreferences
  Future<String?> _refreshFirebaseToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final token = await user.getIdToken(true);
    if (token == null) return null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyAuthToken, token);
    return token;
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('🔵 [API] GET request to: $path');
        if (queryParameters != null && queryParameters.isNotEmpty) {
          debugPrint('   🔍 Query params: $queryParameters');
        }
      }
      return await _dio.get(path, queryParameters: queryParameters);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [API] GET request failed: $e');
      }
      rethrow;
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    try {
      if (kDebugMode) {
        debugPrint('🟢 [API] POST request to: $path');
        if (data != null) {
          debugPrint('   📦 POST data: $data');
        }
      }
      return await _dio.post(path, data: data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [API] POST request failed: $e');
      }
      rethrow;
    }
  }

  Future<Response> put(String path, {dynamic data}) async {
    try {
      if (kDebugMode) {
        debugPrint('🟡 [API] PUT request to: $path');
        if (data != null) {
          debugPrint('   📦 PUT data: $data');
        }
      }
      return await _dio.put(path, data: data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [API] PUT request failed: $e');
      }
      rethrow;
    }
  }

  Future<Response> patch(String path, {dynamic data}) async {
    try {
      if (kDebugMode) {
        debugPrint('🟣 [API] PATCH request to: $path');
        if (data != null) {
          debugPrint('   📦 PATCH data: $data');
        }
      }
      return await _dio.patch(path, data: data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [API] PATCH request failed: $e');
      }
      rethrow;
    }
  }

  Future<Response> delete(String path) async {
    try {
      if (kDebugMode) {
        debugPrint('🔴 [API] DELETE request to: $path');
      }
      return await _dio.delete(path);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [API] DELETE request failed: $e');
      }
      rethrow;
    }
  }
  
  /// Test backend connectivity
  /// Returns true if backend is reachable, false otherwise
  Future<bool> testConnection() async {
    try {
      if (kDebugMode) {
        debugPrint('🧪 [API] Testing backend connectivity...');
        debugPrint('   URL: ${AppConstants.healthCheckUrl}');
      }
      
      // Use a separate Dio instance for health check to avoid interceptors
      final healthCheckDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      
      final response = await healthCheckDio.get(AppConstants.healthCheckUrl);
      
      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ [API] Backend is reachable');
          debugPrint('   Response: ${response.data}');
        }
        return true;
      } else {
        if (kDebugMode) {
          debugPrint('⚠️  [API] Backend returned status ${response.statusCode}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [API] Backend connectivity test failed: $e');
      }
      return false;
    }
  }
  
  /// Get platform name for logging
  static String _getPlatformName() {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
}
