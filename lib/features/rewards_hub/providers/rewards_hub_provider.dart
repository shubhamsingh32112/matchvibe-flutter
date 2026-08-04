import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/rewards_hub_models.dart';
import '../services/rewards_hub_service.dart';

final rewardsHubServiceProvider = Provider<RewardsHubService>((ref) {
  return RewardsHubService();
});

class RewardsHubNotifier extends StateNotifier<AsyncValue<RewardsHubData?>> {
  RewardsHubNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;
  final _service = RewardsHubService();

  Future<void> load({bool silent = false}) async {
    if (!silent) state = const AsyncValue.loading();
    try {
      final data = await _service.getHub();
      state = AsyncValue.data(data);
    } catch (e, st) {
      if (!silent) state = AsyncValue.error(e, st);
    }
  }

  Future<RewardsClaimResult> claim(String taskKey) async {
    final result = await _service.claim(taskKey);
    if (result.coinsCredited > 0 || result.balance > 0) {
      _ref
          .read(authProvider.notifier)
          .updateCoinsOptimistically(result.balance);
    }
    await load(silent: true);
    return result;
  }
}

final rewardsHubProvider =
    StateNotifierProvider<RewardsHubNotifier, AsyncValue<RewardsHubData?>>(
  (ref) => RewardsHubNotifier(ref),
);
