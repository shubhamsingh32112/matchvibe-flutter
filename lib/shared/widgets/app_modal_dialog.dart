import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Opens a centered modal dialog with app-consistent padding and sizing.
///
/// Intended for onboarding / blocking flows where we do not want the user to
/// dismiss the modal via outside tap or back navigation.
Future<T?> showAppModalDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  bool barrierDismissible = false,
  Color? barrierColor,
  EdgeInsets? insetPadding,
  double maxWidth = 520,
  double maxHeightFraction = 0.86,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.45),
    builder: (ctx) {
      final mq = MediaQuery.of(ctx);
      final screenW = mq.size.width;
      final horizontal = screenW < 360 ? 12.0 : 20.0;
      final vertical = screenW < 360 ? 16.0 : 24.0;
      final resolvedInset =
          insetPadding ??
          EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);

      final maxHeight =
          mq.size.height * math.min(0.92, math.max(0.5, maxHeightFraction));
      final maxContentWidth = math.min(
        math.min(maxWidth, screenW * 0.94),
        math.max(240.0, screenW - horizontal * 2),
      );

      return PopScope(
        canPop: barrierDismissible,
        child: Dialog(
          insetPadding: resolvedInset,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxContentWidth,
              maxHeight: maxHeight,
            ),
            child: builder(ctx),
          ),
        ),
      );
    },
  );
}
