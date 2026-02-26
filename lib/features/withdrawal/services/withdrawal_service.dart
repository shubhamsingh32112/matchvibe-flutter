import 'package:flutter/foundation.dart';
import '../../../core/api/api_client.dart';
import '../models/withdrawal_model.dart';

class WithdrawalService {
  final ApiClient _apiClient = ApiClient();

  /// Request a withdrawal (creator only).
  /// Returns the created WithdrawalRequest on success.
  Future<WithdrawalRequest> requestWithdrawal(int amount) async {
    try {
      debugPrint('💸 [WITHDRAWAL] Requesting withdrawal of $amount coins...');
      final response = await _apiClient.post(
        '/creator/withdraw',
        data: {'amount': amount},
      );

      if (response.statusCode == 201 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        debugPrint('✅ [WITHDRAWAL] Request submitted: ${data['withdrawalId']}');
        return WithdrawalRequest.fromJson(data);
      } else {
        final error = response.data['error'] ?? 'Unknown error';
        throw Exception(error);
      }
    } catch (e) {
      debugPrint('❌ [WITHDRAWAL] Error requesting withdrawal: $e');
      rethrow;
    }
  }

  /// Fetch the creator's own withdrawal history.
  Future<List<WithdrawalRequest>> getMyWithdrawals() async {
    try {
      debugPrint('📋 [WITHDRAWAL] Fetching my withdrawals...');
      final response = await _apiClient.get('/creator/withdrawals');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> list = response.data['data']['withdrawals'] ?? [];
        debugPrint('✅ [WITHDRAWAL] Fetched ${list.length} withdrawals');
        return list
            .map((json) => WithdrawalRequest.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        final error = response.data['error'] ?? 'Unknown error';
        throw Exception(error);
      }
    } catch (e) {
      debugPrint('❌ [WITHDRAWAL] Error fetching withdrawals: $e');
      rethrow;
    }
  }
}
