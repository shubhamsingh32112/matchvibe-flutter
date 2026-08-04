import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../models/telegram_reward_status.dart';

class TelegramRewardService {
  final ApiClient _apiClient = ApiClient();

  Future<TelegramRewardStatus> getStatus() async {
    try {
      final response = await _apiClient.get('/rewards/telegram/status');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return TelegramRewardStatus.fromJson(
          response.data['data'] as Map<String, dynamic>,
        );
      }
      throw TelegramRewardException(
        response.data['error']?.toString() ??
            response.data['message']?.toString() ??
            'Failed to load Telegram reward status',
        code: response.data['code']?.toString(),
      );
    } on DioException catch (e) {
      throw _mapDio(e, 'Failed to load Telegram reward status');
    }
  }

  Future<TelegramLinkToken> createLinkToken() async {
    try {
      final response = await _apiClient.post('/rewards/telegram/link-token');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return TelegramLinkToken.fromJson(
          response.data['data'] as Map<String, dynamic>,
        );
      }
      throw TelegramRewardException(
        response.data['error']?.toString() ??
            response.data['message']?.toString() ??
            'Failed to create Telegram link',
        code: response.data['code']?.toString(),
      );
    } on DioException catch (e) {
      throw _mapDio(e, 'Failed to create Telegram link');
    }
  }

  Future<TelegramVerifyResult> verify() async {
    try {
      final response = await _apiClient.post('/rewards/telegram/verify');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return TelegramVerifyResult.fromJson(
          response.data['data'] as Map<String, dynamic>,
        );
      }
      throw TelegramRewardException(
        response.data['error']?.toString() ??
            response.data['message']?.toString() ??
            'Failed to verify Telegram reward',
        code: response.data['code']?.toString(),
      );
    } on DioException catch (e) {
      throw _mapDio(e, 'Failed to verify Telegram reward');
    }
  }

  TelegramRewardException _mapDio(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      return TelegramRewardException(
        data['error']?.toString() ??
            data['message']?.toString() ??
            fallback,
        code: data['code']?.toString(),
      );
    }
    return TelegramRewardException(fallback);
  }
}
