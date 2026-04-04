import 'package:flutter/material.dart';

enum _ToastKind { success, error, info }

/// Consistent floating snackbars aligned with Material 3 / app theme.
class AppToast {
  AppToast._();

  static const Duration _defaultDuration = Duration(seconds: 4);

  static void showSuccess(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    _show(context, message, _ToastKind.success, duration ?? _defaultDuration);
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    _show(context, message, _ToastKind.error, duration ?? _defaultDuration);
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    _show(context, message, _ToastKind.info, duration ?? _defaultDuration);
  }

  /// Error toast with a single action (e.g. Retry).
  static void showErrorWithAction(
    BuildContext context,
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
    Duration? duration,
  }) {
    if (!context.mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final background = scheme.errorContainer;
    final foreground = scheme.onErrorContainer;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: background,
        duration: duration ?? _defaultDuration,
        content: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: foreground, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: actionLabel,
          textColor: foreground,
          onPressed: onAction,
        ),
      ),
    );
  }

  static void _show(
    BuildContext context,
    String message,
    _ToastKind kind,
    Duration duration,
  ) {
    if (!context.mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);

    late Color background;
    late Color foreground;
    late IconData icon;

    switch (kind) {
      case _ToastKind.success:
        background = scheme.primaryContainer;
        foreground = scheme.onPrimaryContainer;
        icon = Icons.check_circle_outline_rounded;
        break;
      case _ToastKind.error:
        background = scheme.errorContainer;
        foreground = scheme.onErrorContainer;
        icon = Icons.error_outline_rounded;
        break;
      case _ToastKind.info:
        background = scheme.surfaceContainerHighest;
        foreground = scheme.onSurfaceVariant;
        icon = Icons.info_outline_rounded;
        break;
    }

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: background,
        duration: duration,
        content: Row(
          children: [
            Icon(icon, color: foreground, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
