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
  EdgeInsets insetPadding = const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
  double maxWidth = 520,
  double maxHeightFraction = 0.86,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.45),
    builder: (ctx) {
      final mq = MediaQuery.of(ctx);
      final maxHeight = mq.size.height * maxHeightFraction;
      return PopScope(
        canPop: barrierDismissible,
        child: Dialog(
          insetPadding: insetPadding,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: builder(ctx),
          ),
        ),
      );
    },
  );
}

