import 'package:flutter/material.dart';
import '../providers/creator_status_provider.dart';

/// App-bar style creator presence indicator (Online / On a call / Offline).
class CreatorStatusLabel extends StatelessWidget {
  const CreatorStatusLabel({
    super.key,
    required this.status,
    this.compact = false,
    this.useAppBarColors = false,
  });

  final CreatorStatus status;
  final bool compact;
  final bool useAppBarColors;

  String get _label {
    switch (status) {
      case CreatorStatus.syncing:
        return 'Syncing';
      case CreatorStatus.online:
        return 'Online';
      case CreatorStatus.busy:
        return 'On a call';
      case CreatorStatus.offline:
        return 'Offline';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSyncing = status == CreatorStatus.syncing;
    final isOnline = status == CreatorStatus.online;
    final isBusy = status == CreatorStatus.busy;

    final Color dotColor;
    final Color textColor;
    if (useAppBarColors) {
      dotColor = isOnline
          ? const Color(0xFF4CAF50)
          : isSyncing
              ? const Color(0xFF81D4FA)
          : isBusy
              ? const Color(0xFFFFB74D)
              : Colors.white.withValues(alpha: 0.55);
      textColor = isOnline
          ? const Color(0xFFB9F6CA)
          : Colors.white.withValues(alpha: 0.85);
    } else {
      dotColor = isOnline
          ? scheme.primary
          : isSyncing
              ? scheme.secondary
          : isBusy
              ? scheme.tertiary
              : scheme.outlineVariant;
      textColor = scheme.onSurface;
    }

    final dotSize = compact ? 10.0 : 12.0;
    final fontSize = compact ? 14.0 : 14.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
            border: useAppBarColors
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 2,
                  )
                : null,
            boxShadow: isOnline && !useAppBarColors
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          _label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }
}
