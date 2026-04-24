import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/referral_apply_messages.dart';
import '../../../core/utils/referral_code_format.dart';
import '../models/referral_model.dart';

class ApplyReferralException implements Exception {
  final String message;
  final String? errorCode;

  ApplyReferralException(this.message, {this.errorCode});

  @override
  String toString() => message;
}

enum ReferralPreviewMode { signup, lateAttach }

class ReferralService {
  final ApiClient _apiClient = ApiClient();

  /// Get current user's referral code and list of referred users.
  Future<ReferralData> getReferrals() async {
    final response = await _apiClient.get('/user/referrals');

    if (response.statusCode == 200 && response.data['success'] == true) {
      return ReferralData.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    }
    throw Exception(
      response.data['error'] as String? ?? 'Failed to load referrals',
    );
  }

  /// Pre-login validation (`GET /referral/preview?code=`). Returns normalized code.
  Future<String> previewReferralCode(
    String rawCode, {
    ReferralPreviewMode mode = ReferralPreviewMode.signup,
  }) async {
    final c = rawCode.trim().toUpperCase();
    if (!ReferralCodeFormat.isValid(c)) {
      throw ApplyReferralException(
        ReferralApplyMessages.forServerCode('INVALID_FORMAT'),
        errorCode: 'INVALID_FORMAT',
      );
    }
    try {
      final response = await _apiClient.get(
        '/referral/preview',
        queryParameters: {
          'code': c,
          'mode': mode == ReferralPreviewMode.lateAttach
              ? 'late_attach'
              : 'signup',
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>?;
        final code = data?['code'] as String?;
        if (code != null && code.isNotEmpty) return code;
      }
      throw ApplyReferralException(
        'Invalid referral code',
        errorCode: 'NOT_FOUND',
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final errCode = data['errorCode'] as String?;
        throw ApplyReferralException(
          data['error'] as String? ??
              ReferralApplyMessages.forServerCode(errCode),
          errorCode: errCode,
        );
      }
      rethrow;
    }
  }

  /// One-time post-signup attach (`POST /user/referral/apply`).
  Future<void> applyLateReferralCode(String rawCode) async {
    final c = rawCode.trim().toUpperCase();
    if (!ReferralCodeFormat.isValid(c)) {
      throw ApplyReferralException(
        'Enter a valid referral code (6 or 8 characters).',
        errorCode: 'INVALID_FORMAT',
      );
    }
    try {
      final response = await _apiClient.post(
        '/user/referral/apply',
        data: {'referralCode': c},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return;
      }
      final data = response.data;
      if (data is Map<String, dynamic>) {
        throw ApplyReferralException(
          data['error'] as String? ?? 'Failed to apply referral code',
          errorCode: data['errorCode'] as String?,
        );
      }
      throw ApplyReferralException('Failed to apply referral code');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        throw ApplyReferralException(
          data['error'] as String? ?? 'Failed to apply referral code',
          errorCode: data['errorCode'] as String?,
        );
      }
      rethrow;
    }
  }
}
