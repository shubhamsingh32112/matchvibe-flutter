import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config_provider.dart';
import '../../../core/services/modal_coordinator_service.dart';
import '../../../shared/widgets/app_modal_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/checkin_provider.dart';
import '../services/checkin_popup_gate.dart';
import '../widgets/daily_checkin_popup.dart';

/// Present Daily Check-in via ModalCoordinator (or immediately for manual open).
class CheckInPresenter {
  CheckInPresenter._();

  static Future<void> enqueueAutoShow({
    required WidgetRef ref,
    required BuildContext context,
  }) async {
    final auth = ref.read(authProvider);
    final user = auth.user;
    final uid = auth.firebaseUser?.uid;
    if (user == null || uid == null) return;
    if (user.role != 'user') return;
    if (!ref.read(appFeaturesProvider).dailyCheckInEnabled) return;

    final modal = ref.read(modalCoordinatorProvider);
    if (modal.onboardingInProgress) return;

    try {
      final status = await ref.read(checkInProvider.notifier).loadStatus(silent: true);
      if (status == null || !status.canClaimToday) return;
      if (!context.mounted) return;

      // IST day from server — never trust device calendar for the gate.
      final istDateKey = _istDateKeyFromUtc(status.serverNow);
      if (CheckInPopupGate.hasAutoShownForDate(istDateKey)) return;

      CheckInPopupGate.markAutoShownForDate(istDateKey);
      final id =
          ref.read(modalCoordinatorProvider.notifier).nextRequestId('checkin');
      ref.read(modalCoordinatorProvider.notifier).enqueue<void>(
            AppModalRequest<void>(
              id: id,
              priority: AppModalPriority.normal,
              dedupeKey: 'daily-checkin-$uid-$istDateKey',
              present: (ctx, _) async {
                await showAppModalDialog<void>(
                  context: ctx,
                  barrierDismissible: true,
                  builder: (_) => DailyCheckInPopup(initialStatus: status),
                );
              },
            ),
          );
    } catch (_) {
      // Silent — popup is non-critical.
    }
  }

  /// Manual / deep-link open — bypasses once-per-launch gate.
  static Future<void> openNow({
    required WidgetRef ref,
    required BuildContext context,
    bool requireClaimable = false,
  }) async {
    final user = ref.read(authProvider).user;
    if (user == null || user.role != 'user') return;
    if (!ref.read(appFeaturesProvider).dailyCheckInEnabled) return;

    try {
      final status =
          await ref.read(checkInProvider.notifier).loadStatus(silent: false);
      if (status == null) return;
      if (requireClaimable && !status.canClaimToday) return;
      if (!context.mounted) return;

      await showAppModalDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => DailyCheckInPopup(initialStatus: status),
      );
    } catch (e) {
      // Caller may toast; swallow here for deep-link path.
    }
  }

  /// Approximate IST YYYY-MM-DD from a UTC instant (IST = UTC+5:30, no DST).
  static String _istDateKeyFromUtc(DateTime utc) {
    final ist = utc.toUtc().add(const Duration(hours: 5, minutes: 30));
    final y = ist.year.toString().padLeft(4, '0');
    final m = ist.month.toString().padLeft(2, '0');
    final d = ist.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
