import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/creator_availability_toggle_provider.dart';
import '../../providers/creator_status_provider.dart';
import '../../theme/creator_home_tokens.dart';

/// Large online/offline switch for creator home header (reference layout).
class CreatorHomeAvailabilitySwitch extends ConsumerWidget {
  const CreatorHomeAvailabilitySwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toggleState = ref.watch(creatorAvailabilityToggleProvider);
    final status = ref.watch(creatorStatusProvider);
    final onCall = status == CreatorStatus.onCall;
    final disabled = toggleState.isSyncing || (onCall && toggleState.toggleOn);

    ref.listen(creatorAvailabilityToggleProvider, (prev, next) {
      final err = next.error;
      if (err != null && err.isNotEmpty && prev?.error != err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
        );
      }
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 1.1,
          child: Switch.adaptive(
            value: toggleState.toggleOn,
            activeTrackColor: CreatorHomeTokens.primaryPurple,
            onChanged: disabled
                ? null
                : (value) {
                    ref
                        .read(creatorAvailabilityToggleProvider.notifier)
                        .setToggle(value);
                  },
          ),
        ),
        Text(
          toggleState.toggleOn ? 'Online' : 'Offline',
          style: const TextStyle(
            color: CreatorHomeTokens.primaryPurple,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
