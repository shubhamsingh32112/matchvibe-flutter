import 'dart:async';

import 'package:flutter/material.dart';

enum _ToastKind { success, error, info }

/// Floating toasts at the **top** of the screen (below status bar).
///
/// Uses the root [Overlay] when available so messages sit above bottom sheets.
class AppToast {
  AppToast._();

  static const Duration _defaultDuration = Duration(seconds: 4);

  static OverlayEntry? _activeEntry;

  static OverlayState? _overlay(BuildContext context) {
    final rootNav = Navigator.maybeOf(context, rootNavigator: true);
    final fromNav = rootNav?.overlay;
    if (fromNav != null) return fromNav;
    return Overlay.maybeOf(context, rootOverlay: true);
  }

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

    final overlay = _overlay(context);
    if (overlay == null) {
      _showSnackBarFallback(
        context,
        message,
        duration ?? _defaultDuration,
        background,
        foreground,
        actionLabel: actionLabel,
        onAction: onAction,
      );
      return;
    }

    _activeEntry?.remove();
    _activeEntry = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _TopToast(
        message: message,
        background: background,
        foreground: foreground,
        icon: Icons.error_outline_rounded,
        duration: duration ?? _defaultDuration,
        actionLabel: actionLabel,
        onAction: onAction,
        removeEntry: () {
          if (identical(_activeEntry, entry)) {
            _activeEntry = null;
          }
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _activeEntry = entry;
    overlay.insert(entry);
  }

  static void _show(
    BuildContext context,
    String message,
    _ToastKind kind,
    Duration duration,
  ) {
    if (!context.mounted) return;
    final scheme = Theme.of(context).colorScheme;

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

    final overlay = _overlay(context);
    if (overlay == null) {
      _showSnackBarFallback(
        context,
        message,
        duration,
        background,
        foreground,
        icon: icon,
      );
      return;
    }

    _activeEntry?.remove();
    _activeEntry = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _TopToast(
        message: message,
        background: background,
        foreground: foreground,
        icon: icon,
        duration: duration,
        removeEntry: () {
          if (identical(_activeEntry, entry)) {
            _activeEntry = null;
          }
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _activeEntry = entry;
    overlay.insert(entry);
  }

  static void _showSnackBarFallback(
    BuildContext context,
    String message,
    Duration duration,
    Color background,
    Color foreground, {
    IconData icon = Icons.info_outline_rounded,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final topPad = MediaQuery.paddingOf(context).top + 8;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          top: topPad,
          bottom: MediaQuery.sizeOf(context).height * 0.55,
        ),
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
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: foreground,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }
}

class _TopToast extends StatefulWidget {
  const _TopToast({
    required this.message,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.duration,
    required this.removeEntry,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final Color background;
  final Color foreground;
  final IconData icon;
  final Duration duration;
  final VoidCallback removeEntry;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast> {
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _hideTimer = Timer(widget.duration, () {
      if (!mounted) return;
      widget.removeEntry();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 8;
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: widget.background,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(widget.icon, color: widget.foreground, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.message,
                  style: TextStyle(
                    color: widget.foreground,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (widget.actionLabel != null && widget.onAction != null)
                TextButton(
                  onPressed: () {
                    widget.onAction!();
                    widget.removeEntry();
                  },
                  child: Text(
                    widget.actionLabel!,
                    style: TextStyle(color: widget.foreground),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
