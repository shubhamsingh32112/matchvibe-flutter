import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_update_model.dart';

class AppUpdatePopupState {
  final AppUpdateModel? pendingUpdate;
  final String? source;

  const AppUpdatePopupState({this.pendingUpdate, this.source});

  AppUpdatePopupState copyWith({
    AppUpdateModel? pendingUpdate,
    String? source,
    bool clear = false,
  }) {
    return AppUpdatePopupState(
      pendingUpdate: clear ? null : (pendingUpdate ?? this.pendingUpdate),
      source: clear ? null : (source ?? this.source),
    );
  }
}

class AppUpdatePopupNotifier extends StateNotifier<AppUpdatePopupState> {
  AppUpdatePopupNotifier() : super(const AppUpdatePopupState());

  void setPendingUpdate(AppUpdateModel? update, {String? source}) {
    state = state.copyWith(
      pendingUpdate: update,
      source: source,
      clear: update == null,
    );
  }

  void clearPendingUpdate() {
    state = state.copyWith(clear: true);
  }
}

final appUpdatePopupProvider =
    StateNotifierProvider<AppUpdatePopupNotifier, AppUpdatePopupState>(
  (ref) => AppUpdatePopupNotifier(),
);
