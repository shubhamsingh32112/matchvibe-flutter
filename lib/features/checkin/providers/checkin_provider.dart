import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/checkin_status_model.dart';
import '../services/checkin_service.dart';

/// Set true when a deep link / FCM tap requests opening the check-in popup.
final checkInDeepLinkIntentProvider = StateProvider<bool>((ref) => false);

/// Bumped on app resume so Home can re-check IST midnight unlock without relaunch.
final checkInResumeTickProvider = StateProvider<int>((ref) => 0);

final checkInServiceProvider = Provider<CheckInService>((ref) {
  return CheckInService();
});

class CheckInNotifier extends StateNotifier<AsyncValue<CheckInStatus?>> {
  CheckInNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;
  final CheckInService _service = CheckInService();

  Future<CheckInStatus?> loadStatus({bool silent = false}) async {
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

  Future<CheckInStatus> claim() async {
    final result = await _service.claim();
    state = AsyncValue.data(result);
    _ref
        .read(authProvider.notifier)
        .updateCoinsOptimistically(result.coinsBalance);
    return result;
  }
}

final checkInProvider =
    StateNotifierProvider<CheckInNotifier, AsyncValue<CheckInStatus?>>((ref) {
  return CheckInNotifier(ref);
});
