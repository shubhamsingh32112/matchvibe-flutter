import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Maps exceptions and API failures to short, user-safe copy.
/// Raw stack traces, Dio dumps, and developer diagnostics must never be returned.
class UserMessageMapper {
  UserMessageMapper._();

  static const String genericFallback =
      'Something went wrong. Please try again.';
  static const String networkFallback =
      'Network error, no connection please try again.';

  /// Primary entry: any thrown object from catch blocks.
  static String userMessageFor(Object? error, {String? fallback}) {
    final fb = fallback ?? genericFallback;
    if (error == null) return fb;

    if (kDebugMode) {
      debugPrint('UserMessageMapper: $error');
    }

    if (error is DioException) {
      return _fromDio(error, fb);
    }
    if (error is String) {
      return fromString(error, fallback: fb);
    }
    return _fromUnknown(error, fb);
  }

  /// Firebase/auth/network heuristics for string errors (e.g. from state.error).
  static String fromString(String raw, {String? fallback}) {
    final fb = fallback ?? genericFallback;
    final error = raw.trim();
    if (error.isEmpty) return fb;

    if (error.contains('Network error, no connection please try again.')) {
      return networkFallback;
    }

    if (error.contains('STREAM_USER_RECOVERY_FAILED')) {
      return 'Chat is temporarily recovering. Please retry in a moment.';
    }
    if (error.contains('STREAM_SERVICE_UNAVAILABLE')) {
      return 'Chat service is temporarily unavailable. Please retry shortly.';
    }

    if (error.contains('network') ||
        error.contains('Network') ||
        error.contains('connection') ||
        error.contains('Connection') ||
        error.contains('Failed host lookup') ||
        error.contains('SocketException') ||
        error.contains('no route to host') ||
        error.contains('No route to host') ||
        error.contains('errno: 113')) {
      return networkFallback;
    }

    if (error.contains('account-exists-with-different-credential')) {
      return 'An account already exists with this email using a different sign-in method.';
    }
    if (error.contains('invalid-credential')) {
      return 'The sign-in credential is invalid or expired. Please try again.';
    }
    if (error.contains('operation-not-allowed')) {
      return 'Google sign-in is not enabled. Please contact support.';
    }
    if (error.contains('user-disabled')) {
      return 'This account has been disabled. Please contact support.';
    }
    if (error.contains('sign_in_canceled') ||
        error.contains('SignInCanceledException')) {
      return 'Sign-in was canceled. Please try again.';
    }
    if (error.contains('sign_in_failed') || error.contains('SignInException')) {
      return 'Google sign-in failed. Please try again.';
    }
    if (error.contains('platform_exception') && error.contains('google')) {
      return 'Google sign-in error. Please ensure Google Play Services is up to date.';
    }

    if (error.contains('invalid-verification-code')) {
      return 'Invalid verification code. Please try again.';
    }
    if (error.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (error.contains('invalid-phone-number')) {
      return 'Invalid phone number. Please check and try again.';
    }
    // Firebase / GCP: phone auth and some auth flows require a billing account
    // on the linked Google Cloud project (see Firebase pricing / Blaze).
    if (error.contains('BILLING_NOT_ENABLED')) {
      return 'Phone sign-in is not available yet: billing must be enabled on the '
          'Firebase/Google Cloud project for this app. Ask your developer to '
          'link a billing account in Google Cloud Console, then retry.';
    }

    if (error.contains('user-not-found')) {
      return 'User not found. Please sign up first.';
    }
    if (error.contains('wrong-password')) {
      return 'Incorrect password. Please try again.';
    }
    if (error.contains('email-already-in-use')) {
      return 'This email is already registered. Please sign in instead.';
    }
    if (error.contains('weak-password')) {
      return 'Password is too weak. Please use a stronger password.';
    }
    if (error.contains('expired') || error.contains('token-expired')) {
      return 'Session expired. Please sign in again.';
    }
    if (error.contains('unauthorized') || error.contains('Unauthorized')) {
      return 'Unauthorized. Please sign in again.';
    }

    if (error.contains('DioException') ||
        error.contains('connection error') ||
        error.contains('Failed host lookup') ||
        error.contains('SocketException') ||
        error.contains('connection refused') ||
        error.contains('Cannot reach server')) {
      return networkFallback;
    }
    if (error.contains('timeout') || error.contains('Timeout')) {
      return networkFallback;
    }
    if (error.contains('500') || error.contains('Internal Server Error')) {
      return 'Server error. Please try again later.';
    }
    if (error.contains('404') || error.contains('Not Found')) {
      return 'Service not found. Please contact support.';
    }
    if (error.contains('Failed to sync user') ||
        error.contains('Failed to sync')) {
      return 'Failed to sync with server. Please check your connection and try again.';
    }

    final lowerError = error.toLowerCase();
    if (lowerError.contains('no address associated') ||
        lowerError.contains('your_desktop_ip') ||
        lowerError.contains('no route to host')) {
      return networkFallback;
    }
    if (lowerError.contains('connection refused') ||
        lowerError.contains('errno: 111') ||
        lowerError.contains('errno: 61') ||
        lowerError.contains('errno: 113')) {
      return networkFallback;
    }

    if (error.length > 160 || error.contains('\n')) {
      return fb;
    }

    if (_isSafeUserFacingMessage(error)) {
      return error;
    }

    return fb;
  }

  static String _fromDio(DioException e, String fb) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The request timed out. Please check your connection and try again.';
      case DioExceptionType.connectionError:
        return networkFallback;
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        final data = e.response?.data;
        String? apiMsg;
        if (data is Map) {
          final err = data['error'];
          final msg = data['message'];
          if (err is String &&
              err.trim().isNotEmpty &&
              _isSafeUserFacingMessage(err)) {
            apiMsg = err.trim();
          } else if (msg is String &&
              msg.trim().isNotEmpty &&
              _isSafeUserFacingMessage(msg)) {
            apiMsg = msg.trim();
          }
          if (apiMsg == null) {
            final codeField = data['code'];
            if (codeField is String && codeField.trim().isNotEmpty) {
              final mapped = _userMessageForApiErrorCode(
                codeField.trim(),
                Map<Object?, Object?>.from(data),
              );
              if (mapped != null) {
                apiMsg = mapped;
              }
            }
          }
        }
        if (apiMsg != null) return apiMsg;
        if (code == 503) {
          final path = e.requestOptions.path.toLowerCase();
          if (path.contains('/chat') || path.contains('/stream')) {
            return 'Chat is temporarily recovering. Please retry in a moment.';
          }
          if (path.contains('/auth') || path.contains('/referral')) {
            return 'Sign-in service is temporarily busy. Please retry in a moment.';
          }
          return 'Service is temporarily unavailable. Please retry in a moment.';
        }
        if (code >= 500) return 'Server error. Please try again later.';
        if (code == 401 || code == 403) {
          return 'Session expired. Please sign in again.';
        }
        if (code >= 400) {
          return 'We couldn\'t complete that request. Please try again.';
        }
        return fb;
      case DioExceptionType.unknown:
        if (e.error is String) {
          return fromString(e.error! as String, fallback: fb);
        }
        return networkFallback;
      case DioExceptionType.badCertificate:
        return 'Secure connection failed. Please try again later.';
    }
  }

  /// Maps backend `code` fields when `error` text is missing or redacted as unsafe.
  static String? _userMessageForApiErrorCode(
    String code,
    Map<Object?, Object?> body,
  ) {
    switch (code) {
      case 'UPLOAD_SESSION_INVALID':
        return 'Upload session expired or was already used. Please pick the photo again.';
      case 'UPLOAD_NOT_FOUND':
        return 'The image did not finish uploading. Please try again.';
      case 'UNSUPPORTED_MIME_TYPE':
        return 'That image format is not supported. Try JPEG or PNG.';
      case 'CLOUDFLARE_IMAGES_ERROR':
        return 'Our image service had a problem. Please try again in a moment.';
      case 'CLOUDFLARE_IMAGES_UNAVAILABLE':
      case 'IMAGES_DISABLED':
        return 'Image uploads are temporarily unavailable. Please try again later.';
      case 'UPLOAD_QUOTA_EXCEEDED':
        final ra = body['retryAfterSeconds'];
        if (ra is num && ra.toInt() > 0) {
          return 'Upload limit reached. Please try again in about ${ra.toInt()} seconds.';
        }
        return 'Upload limit reached. Please try again in a little while.';
      case 'INVALID_PURPOSE':
      case 'INVALID_SIZE':
        return 'Invalid upload request. Please update the app and try again.';
      case 'FILE_TOO_LARGE':
        return 'That file is too large. Try a smaller image.';
      case 'TOO_MANY_SAMPLES':
        return 'Too much data in one request. Please try again.';
      case 'INVALID_SAMPLES':
        return 'Invalid request. Please try again.';
      default:
        return null;
    }
  }

  static String _fromUnknown(Object error, String fb) {
    if (error is FormatException) {
      return 'Invalid data. Please try again.';
    }

    var text = error.toString();
    if (text.startsWith('Exception: ')) {
      text = text.substring(11).trim();
    } else if (text.startsWith('Error: ')) {
      text = text.substring(7).trim();
    }

    if (text.length > 160 || text.contains('\n')) {
      return fb;
    }

    if (_looksLikeTechnicalException(text)) {
      return fb;
    }

    if (_isSafeUserFacingMessage(text)) {
      return text;
    }

    return fb;
  }

  /// Backend/user copy we are willing to show verbatim.
  static bool _isSafeUserFacingMessage(String s) {
    if (s.length > 200) return false;
    if (s.contains('\n')) return false;
    if (_looksLikeTechnicalException(s)) return false;
    return true;
  }

  static bool _looksLikeTechnicalException(String s) {
    final lower = s.toLowerCase();
    if (lower.contains('dioexception')) return true;
    if (lower.contains('socketexception')) return true;
    if (lower.contains('failed host lookup')) return true;
    if (lower.contains('stacktrace')) return true;
    if (lower.contains('http://') || lower.contains('https://')) return true;
    if (lower.contains('errno:')) return true;
    if (lower.contains(' at ')) return true;
    if (regExpDartFrame.hasMatch(s)) return true;
    return false;
  }

  static final regExpDartFrame = RegExp(r'#\d+\s+');

  static String forCallFailure(Object? error) {
    return userMessageFor(
      error,
      fallback: 'Couldn\'t connect the call. Please try again.',
    );
  }
}
