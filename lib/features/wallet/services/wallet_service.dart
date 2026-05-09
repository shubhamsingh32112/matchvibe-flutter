import 'package:flutter/foundation.dart';
import '../../../core/api/api_client.dart';

class WalletService {
  final ApiClient _apiClient = ApiClient();

  /// Add coins to user account
  Future<int> addCoins(int coins) async {
    try {
      debugPrint('💰 [WALLET] Adding $coins coins to account...');
      final response = await _apiClient.post('/user/coins', data: {'coins': coins});
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final newCoins = response.data['data']['user']['coins'] as int;
        debugPrint('✅ [WALLET] Coins added successfully. New balance: $newCoins');
        return newCoins;
      } else {
        throw Exception('Failed to add coins: ${response.data['error']}');
      }
    } catch (e) {
      debugPrint('❌ [WALLET] Error adding coins: $e');
      rethrow;
    }
  }

}
