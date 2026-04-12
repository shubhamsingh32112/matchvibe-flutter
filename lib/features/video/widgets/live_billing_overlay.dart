import 'dart:async';

import 'package:flutter/material.dart';

import '../providers/call_billing_provider.dart';

/// Formats billed seconds as `M:SS` (no hours split — rare for caps).
String formatBillingMmSs(int seconds) {
  if (seconds < 0) seconds = 0;
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// Server-driven billing strip: frosted light card readable on video.
class LiveBillingOverlay extends StatefulWidget {
  final CallBillingState billing;
  final bool isCreator;

  const LiveBillingOverlay({
    super.key,
    required this.billing,
    required this.isCreator,
  });

  @override
  State<LiveBillingOverlay> createState() => _LiveBillingOverlayState();
}

class _LiveBillingOverlayState extends State<LiveBillingOverlay> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.billing;
    final scheme = Theme.of(context).colorScheme;
    final timeLabel = formatBillingMmSs(b.elapsedSeconds);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final stale = b.lastServerTimestampMs != null &&
        nowMs - b.lastServerTimestampMs! > 3500;

    final accent = scheme.primary;
    final fg = scheme.onSurface;

    final child = Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            color: fg,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_outlined, size: 18, color: accent),
              const SizedBox(width: 8),
              Text(timeLabel),
              const SizedBox(width: 12),
              if (widget.isCreator) ...[
                Icon(Icons.paid_outlined, size: 18, color: accent),
                const SizedBox(width: 6),
                Text(_formatEarnings(b.estimatedCreatorEarningsDisplay)),
              ] else ...[
                Icon(Icons.monetization_on_outlined, size: 18, color: accent),
                const SizedBox(width: 6),
                Text('${b.estimatedUserCoins}'),
                if (b.remainingSeconds != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '· ~${b.remainingSeconds}s left',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
              if (stale) ...[
                const SizedBox(width: 8),
                Icon(Icons.cloud_off_outlined,
                    size: 16, color: scheme.error.withValues(alpha: 0.95)),
              ],
            ],
          ),
        ),
      ),
    );

    final semanticsLabel = widget.isCreator
        ? 'Billed time $timeLabel, earnings ${_formatEarnings(b.estimatedCreatorEarningsDisplay)} coins'
        : 'Billed time $timeLabel, ${b.estimatedUserCoins} coins in wallet'
            '${b.remainingSeconds != null ? ', about ${b.remainingSeconds} seconds of call time remaining' : ''}';

    return Semantics(
      label: semanticsLabel,
      child: child,
    );
  }
}

String _formatEarnings(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2);
}
