import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/creator_availability_toggle_provider.dart';
import '../providers/creator_status_provider.dart';
import 'creator_status_label.dart';

/// App-bar switch: explicit creator online/offline for fans.
class CreatorAvailabilityToggle extends ConsumerWidget {
  const CreatorAvailabilityToggle({
    super.key,
    this.compact = true,
    this.useAppBarColors = true,
  });

  final bool compact;
  final bool useAppBarColors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toggleState = ref.watch(creatorAvailabilityToggleProvider);
    final status = ref.watch(creatorStatusProvider);
    final onCall = status == CreatorStatus.onCall;
    // Allow toggle ON during on_call (ghost recovery); block toggle OFF during live call.
    final disabled = toggleState.isSyncing || (onCall && toggleState.toggleOn);

    ref.listen(creatorAvailabilityToggleProvider, (prev, next) {
      final err = next.error;
      if (err != null && err.isNotEmpty && prev?.error != err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
        );
      }
    });

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CreatorStatusLabel(
          status: status,
          compact: compact,
          useAppBarColors: useAppBarColors,
        ),
        const SizedBox(width: 4),
        Switch.adaptive(
          value: toggleState.toggleOn,
          onChanged: disabled
              ? null
              : (value) {
                  ref
                      .read(creatorAvailabilityToggleProvider.notifier)
                      .setToggle(value);
                },
        ),
      ],
    );
  }
}
