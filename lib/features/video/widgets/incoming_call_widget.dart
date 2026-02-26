import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import '../../auth/providers/auth_provider.dart';
import '../controllers/call_connection_controller.dart';
import '../utils/call_remote_image_resolver.dart';

/// Widget to display incoming call notification.
///
/// Shows Accept / Reject buttons when idle.
/// Shows "Connecting…" spinner when the controller is preparing / joining.
///
/// ❌ Does NOT navigate or join — delegates entirely to [CallConnectionController].
class IncomingCallWidget extends ConsumerWidget {
  final Call incomingCall;
  final String? fallbackImageUrl;

  /// Called when the call is dismissed (rejected by creator or cancelled by caller).
  /// The parent [IncomingCallListener] uses this to mark the call ID as handled
  /// and prevent the overlay from re-appearing.
  final VoidCallback? onDismiss;

  const IncomingCallWidget({
    super.key,
    required this.incomingCall,
    this.fallbackImageUrl,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final callPhase = ref.watch(callConnectionControllerProvider).phase;
    final currentUserId = ref.watch(authProvider).firebaseUser?.uid;
    final isProcessing = callPhase == CallConnectionPhase.preparing ||
        callPhase == CallConnectionPhase.joining;
    final remoteImageUrl = resolveRemoteImageUrl(
      call: incomingCall,
      currentUserId: currentUserId,
      fallbackImageUrl: fallbackImageUrl,
      enableDebugLogs: true,
      debugSourceTag: 'incoming',
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (remoteImageUrl != null)
          Image.network(
            remoteImageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: scheme.surface),
          )
        else
          Container(color: scheme.surface),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.35),
                Colors.black.withValues(alpha: 0.6),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Caller info
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: ClipOval(
                    child: remoteImageUrl != null
                        ? Image.network(
                            remoteImageUrl,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white,
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isProcessing ? 'Connecting…' : 'Incoming Call',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Video Call',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const Spacer(),
                // Action buttons or connecting spinner
                if (isProcessing)
                  const CircularProgressIndicator(color: Colors.white)
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Reject button
                      _CallActionButton(
                        icon: Icons.call_end,
                        label: 'Reject',
                        color: Colors.red,
                        onPressed: () async {
                          try {
                            await incomingCall.reject();
                            debugPrint('❌ [CALL] Call rejected by creator');
                          } catch (e) {
                            debugPrint('❌ [CALL] Error rejecting call: $e');
                          }
                          // Dismiss overlay immediately so it doesn't linger
                          onDismiss?.call();
                        },
                      ),
                      // Accept button — delegates to controller
                      _CallActionButton(
                        icon: Icons.call,
                        label: 'Accept',
                        color: Colors.green,
                        onPressed: () {
                          ref
                              .read(callConnectionControllerProvider.notifier)
                              .acceptIncomingCall(incomingCall);
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ],
    );
  }
}
