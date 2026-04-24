import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_update_model.dart';

class AppUpdatePopupState {
  final AppUpdateModel? pendingUpdate;

  const AppUpdatePopupState({this.pendingUpdate});

  AppUpdatePopupState copyWith({AppUpdateModel? pendingUpdate, bool clear = false}) {
    return AppUpdatePopupState(
      pendingUpdate: clear ? null : (pendingUpdate ?? this.pendingUpdate),
    );
  }
}

class AppUpdatePopupNotifier extends StateNotifier<AppUpdatePopupState> {
  AppUpdatePopupNotifier() : super(const AppUpdatePopupState());

  void setPendingUpdate(AppUpdateModel? update) {
    state = state.copyWith(pendingUpdate: update, clear: update == null);
  }

  void clearPendingUpdate() {
    state = state.copyWith(clear: true);
  }
}

final appUpdatePopupProvider =
    StateNotifierProvider<AppUpdatePopupNotifier, AppUpdatePopupState>(
  (ref) => AppUpdatePopupNotifier(),
);
