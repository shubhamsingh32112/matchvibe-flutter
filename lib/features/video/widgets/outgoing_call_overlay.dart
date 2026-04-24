import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../controllers/call_connection_controller.dart';
import 'call_dial_card.dart';

/// Half-screen card while a **user** is dialing / connecting; bottom half passes
/// gestures through to the underlying route (e.g. home grid).
class OutgoingCallOverlay extends ConsumerStatefulWidget {
  const OutgoingCallOverlay({super.key});

  @override
  ConsumerState<OutgoingCallOverlay> createState() =>
      _OutgoingCallOverlayState();
}

class _OutgoingCallOverlayState extends ConsumerState<OutgoingCallOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _barController;
  bool? _wakelockHeld;

  @override
  void initState() {
    super.initState();
    _barController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _barController.dispose();
    if (_wakelockHeld == true) {
      WakelockPlus.disable();
    }
    super.dispose();
  }

  void _syncWakelock(bool want) {
    if (_wakelockHeld == want) return;
    _wakelockHeld = want;
    if (want) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callConnectionControllerProvider);
    final visible = callState.isOutgoing &&
        (callState.phase == CallConnectionPhase.preparing ||
            callState.phase == CallConnectionPhase.joining);

    _syncWakelock(visible);

    if (!visible) {
      return const SizedBox.shrink();
    }

    final name = (callState.outgoingCreatorName ?? 'Creator').trim();
    final age = callState.outgoingCreatorAge;
    final country = callState.outgoingCreatorCountry?.trim();
    final imageUrl = callState.remoteImageFallbackUrl;
    final connecting = callState.creatorAcceptedForOutgoing;

    final nameLine =
        age != null ? '$name, $age' : (name.isEmpty ? 'Creator' : name);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await ref.read(callConnectionControllerProvider.notifier).endCall();
        }
      },
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
                child: CallDialCard(
                  nameLine: nameLine,
                  country: country,
                  imageUrl: imageUrl,
                  statusText: connecting
                      ? 'Connecting...'
                      : 'Awaiting response...',
                  showConnectingBar: connecting,
                  connectingBarAnimation: _barController,
                  onHangUp: () {
                    ref.read(callConnectionControllerProvider.notifier).endCall();
                  },
                ),
              ),
            ),
            Expanded(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.transparent,
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
