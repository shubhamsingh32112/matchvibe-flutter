import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/coin_purchase_popup.dart';
import '../../../shared/widgets/app_modal_bottom_sheet.dart';
import '../../auth/providers/auth_provider.dart';
import '../controllers/call_connection_controller.dart';
import '../utils/call_remote_image_resolver.dart';
import '../utils/call_remote_participant_display.dart';
import 'call_dial_card.dart';

/// Widget to display incoming call notification.
///
/// Shows Accept / Reject buttons when idle.
/// Shows "Connecting…" + progress bar when the controller is preparing / joining.
///
/// Does not navigate or join — delegates entirely to [CallConnectionController].
class IncomingCallWidget extends ConsumerStatefulWidget {
  final Call incomingCall;
  final String? fallbackImageUrl;

  /// Called when the call is dismissed (rejected by creator or cancelled by caller).
  final VoidCallback? onDismiss;

  const IncomingCallWidget({
    super.key,
    required this.incomingCall,
    this.fallbackImageUrl,
    this.onDismiss,
  });

  @override
  ConsumerState<IncomingCallWidget> createState() => _IncomingCallWidgetState();
}

class _IncomingCallWidgetState extends ConsumerState<IncomingCallWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _barController;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callPhase = ref.watch(callConnectionControllerProvider).phase;
    final currentUserId = ref.watch(authProvider).firebaseUser?.uid;
    final isProcessing = callPhase == CallConnectionPhase.preparing ||
        callPhase == CallConnectionPhase.joining;

    String? remoteImageUrl = (widget.fallbackImageUrl != null &&
            widget.fallbackImageUrl!.isNotEmpty)
        ? widget.fallbackImageUrl
        : resolveRemoteImageUrl(
            call: widget.incomingCall,
            currentUserId: currentUserId,
            fallbackImageUrl: widget.fallbackImageUrl,
            enableDebugLogs: true,
            debugSourceTag: 'incoming',
          );

    debugPrint(
        '🖼️ [INCOMING CALL WIDGET] Image URL: ${remoteImageUrl ?? "null"} (fallback: ${widget.fallbackImageUrl ?? "null"})');

    final u = remoteImageUrl;
    final String? photoUrl =
        u != null && u.trim().isNotEmpty ? u.trim() : null;

    final display = resolveRemoteParticipantDisplay(
      call: widget.incomingCall,
      currentUserId: currentUserId,
      fallbackName: 'Caller',
    );

    final footer = isProcessing
        ? null
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CallActionButton(
                icon: Icons.call_end,
                label: 'Reject',
                color: AppPalette.primaryRed,
                labelColor: AppPalette.onSurface,
                onPressed: () async {
                  try {
                    await widget.incomingCall.reject();
                    debugPrint('❌ [CALL] Call rejected by creator');
                  } catch (e) {
                    debugPrint('❌ [CALL] Error rejecting call: $e');
                  }
                  widget.onDismiss?.call();
                },
              ),
              _CallActionButton(
                icon: Icons.call,
                label: 'Accept',
                color: AppPalette.success,
                labelColor: AppPalette.onSurface,
                onPressed: () {
                  final authState = ref.read(authProvider);
                  final user = authState.user;
                  if (user != null &&
                      user.role == 'user' &&
                      user.coins < 10) {
                    showAppModalBottomSheet(
                      context: context,
                      builder: (context) => const CoinPurchaseBottomSheet(),
                    );
                    return;
                  }
                  ref
                      .read(callConnectionControllerProvider.notifier)
                      .acceptIncomingCall(widget.incomingCall);
                },
              ),
            ],
          );

    return SafeArea(
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
                nameLine: display.nameLine,
                country: display.country,
                imageUrl: photoUrl,
                statusText: isProcessing ? 'Connecting...' : 'Awaiting response...',
                showConnectingBar: isProcessing,
                connectingBarAnimation: _barController,
                showHangUpButton: isProcessing,
                onHangUp: isProcessing
                    ? () {
                        ref.read(callConnectionControllerProvider.notifier).endCall();
                      }
                    : null,
                bottomSectionReplacement: footer,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              ),
            ),
          ),
          Expanded(
            child: IgnorePointer(
              child: ColoredBox(
                color: Colors.transparent,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color labelColor;
  final VoidCallback onPressed;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.labelColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
