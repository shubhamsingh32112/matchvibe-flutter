import 'package:flutter/material.dart';

/// Opens a modal bottom sheet with a transparent sheet background so the
/// [barrierColor] scrim shows through above [DraggableScrollableSheet] content.
Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  bool isScrollControlled = true,
  bool useSafeArea = false,
  double? barrierOpacity,
  bool suppressBarrier = false,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  final opacity = suppressBarrier ? 0.0 : (barrierOpacity ?? 0.35);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: opacity),
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    builder: builder,
  );
}
