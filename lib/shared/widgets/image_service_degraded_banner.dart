/// Non-blocking banner shown when the backend image pipeline is degraded.
///
/// Hooks into [imageServiceDegradedProvider]; visible while
/// `state.isDegraded == true`, then persists for at least 5 seconds after
/// the flag flips off so users notice the recovery.
///
/// Designed to be wrapped around any scaffold body (top of stack). It is
/// intentionally borderless and small so it never blocks layout or input.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/image_service_degraded_provider.dart';

class ImageServiceDegradedBanner extends ConsumerStatefulWidget {
  const ImageServiceDegradedBanner({super.key});

  static const Duration _minVisibleAfterClear = Duration(seconds: 5);

  @override
  ConsumerState<ImageServiceDegradedBanner> createState() =>
      _ImageServiceDegradedBannerState();
}

class _ImageServiceDegradedBannerState
    extends ConsumerState<ImageServiceDegradedBanner> {
  bool _wasDegraded = false;
  DateTime? _clearedAt;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageServiceDegradedProvider);

    final now = DateTime.now();
    if (state.isDegraded) {
      _wasDegraded = true;
      _clearedAt = null;
    } else if (_wasDegraded && _clearedAt == null) {
      _clearedAt = now;
    }

    final cleared = _clearedAt;
    final keepVisible = state.isDegraded ||
        (cleared != null &&
            now.difference(cleared) <
                ImageServiceDegradedBanner._minVisibleAfterClear);

    if (cleared != null) {
      final remaining = ImageServiceDegradedBanner._minVisibleAfterClear -
          now.difference(cleared);
      if (remaining > Duration.zero) {
        Future<void>.delayed(remaining, () {
          if (mounted) setState(() {});
        });
      }
    }

    if (!keepVisible) {
      _wasDegraded = false;
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final isHealing = !state.isDegraded;
    final label = isHealing
        ? 'Image service recovered'
        : 'Image service is degraded — uploads will retry automatically';
    final bg = isHealing
        ? scheme.tertiaryContainer
        : scheme.errorContainer;
    final fg = isHealing
        ? scheme.onTertiaryContainer
        : scheme.onErrorContainer;
    return Material(
      color: bg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                isHealing ? Icons.check_circle_outline : Icons.cloud_off,
                color: fg,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
