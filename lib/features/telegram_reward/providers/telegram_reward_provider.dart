import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/telegram_reward_status.dart';
import '../services/telegram_reward_service.dart';

final telegramRewardServiceProvider = Provider<TelegramRewardService>((ref) {
  return TelegramRewardService();
});

class TelegramRewardNotifier
    extends StateNotifier<AsyncValue<TelegramRewardStatus?>> {
  TelegramRewardNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;
  final TelegramRewardService _service = TelegramRewardService();
  bool _verifying = false;

  bool get isVerifying => _verifying;

  Future<TelegramRewardStatus?> loadStatus({bool silent = false}) async {
    if (!silent) {
      state = const AsyncValue.loading();
    }
    try {
      final status = await _service.getStatus();
      state = AsyncValue.data(status);
      return status;
    } catch (e, st) {
      if (!silent) {
        state = AsyncValue.error(e, st);
      }
      rethrow;
    }
  }

  Future<TelegramLinkToken> createLinkToken() {
    return _service.createLinkToken();
  }

  Future<TelegramVerifyResult> verify() async {
    if (_verifying) {
      throw TelegramRewardException('Verification already in progress');
    }
    _verifying = true;
    try {
      final result = await _service.verify();
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncValue.data(
          current.copyWith(
            claimed: true,
            coinsBalance: result.balance,
          ),
        );
      } else {
        await loadStatus(silent: true);
      }
      _ref
          .read(authProvider.notifier)
          .updateCoinsOptimistically(result.balance);
      return result;
    } finally {
      _verifying = false;
    }
  }
}

final telegramRewardProvider = StateNotifierProvider<TelegramRewardNotifier,
    AsyncValue<TelegramRewardStatus?>>((ref) {
  return TelegramRewardNotifier(ref);
});
