import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import '../controllers/call_connection_controller.dart';

<<<<<<< HEAD
/// Widget to display incoming call notification.
///
/// Shows Accept / Reject buttons when idle.
/// Shows "Connecting…" spinner when the controller is preparing / joining.
///
/// ❌ Does NOT navigate or join — delegates entirely to [CallConnectionController].
=======
/// 🔥 Fire-and-forget background work for accepting calls
/// 
/// This runs AFTER navigation has already happened.
/// All errors are logged but don't affect UI (call screen handles state).
Future<void> _acceptAndJoinInBackground(Call call) async {
  try {
    if (kDebugMode) {
      debugPrint('🔄 [ACCEPT BG] Starting background accept flow...');
    }
    
    // 1. Request permissions (may show system dialog)
    final hasPermissions = await PermissionService.ensurePermissions(video: true);
    if (!hasPermissions) {
      if (kDebugMode) {
        debugPrint('❌ [ACCEPT BG] Permissions denied - call will fail on call screen');
      }
      return;
    }
    if (kDebugMode) {
      debugPrint('✅ [ACCEPT BG] Permissions granted');
    }
    
    // 2. Accept the call (signals intent to Stream)
    await call.accept();
    if (kDebugMode) {
      debugPrint('✅ [ACCEPT BG] Call accepted');
    }
    
    // 3. Join the call (fire-and-forget - don't await)
    // Stream SDK handles retries internally
    // Call screen reacts to call.state changes
    unawaited(call.join().then((_) {
      if (kDebugMode) {
        debugPrint('✅ [ACCEPT BG] Join completed');
      }
    }).catchError((error) {
      if (kDebugMode) {
        debugPrint('❌ [ACCEPT BG] Join error: $error');
      }
      // Call screen handles this via call.state stream
    }));
    
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ [ACCEPT BG] Error in accept flow: $e');
    }
    // Call screen handles this via call.state stream
  }
}

/// Widget to display incoming call notification
/// 
/// Shows when StreamVideo.instance.state.incomingCall is not null
/// Provides Accept and Reject buttons
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
class IncomingCallWidget extends ConsumerWidget {
  final Call incomingCall;

  /// Called when the call is dismissed (rejected by creator or cancelled by caller).
  /// The parent [IncomingCallListener] uses this to mark the call ID as handled
  /// and prevent the overlay from re-appearing.
  final VoidCallback? onDismiss;

  const IncomingCallWidget({
    super.key,
    required this.incomingCall,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final callPhase = ref.watch(callConnectionControllerProvider).phase;
    final isProcessing = callPhase == CallConnectionPhase.preparing ||
        callPhase == CallConnectionPhase.joining;

    return Container(
      color: scheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Caller info
              CircleAvatar(
                radius: 60,
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  Icons.person,
                  size: 60,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isProcessing ? 'Connecting…' : 'Incoming Call',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Video Call',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const Spacer(),
<<<<<<< HEAD
              // Action buttons or connecting spinner
              if (isProcessing)
                const CircularProgressIndicator()
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
=======
              // Action buttons
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
                        // Call reject() to properly reject the incoming call
                        await incomingCall.reject();
                        if (kDebugMode) {
                          debugPrint('❌ [CALL] Call rejected by creator');
                        }
                      } catch (e) {
                        if (kDebugMode) {
                          debugPrint('❌ [CALL] Error rejecting call: $e');
                        }
                      }
                    },
                  ),
                  // Accept button
                  _CallActionButton(
                    icon: Icons.call,
                    label: 'Accept',
                    color: Colors.green,
                    onPressed: () {
                      if (kDebugMode) {
                        debugPrint('🔥 [ACCEPT] Accept tapped - navigating IMMEDIATELY');
                        debugPrint('   Call ID: ${incomingCall.id}');
                      }
                      
                      // 🔥 CRITICAL FIX: Navigate IMMEDIATELY (zero perceived delay)
                      // This MUST be the FIRST line - no async work before this
                      // Navigation triggers _hasAcceptedCall = true in IncomingCallListener
                      CallNavigationService.navigateToCall(incomingCall);
                      
                      // 🔥 Do ALL heavy work in background (fire-and-forget)
                      // Permissions, accept(), join() - all async, all fire-and-forget
                      // UI has already transitioned - these run in background
                      unawaited(_acceptAndJoinInBackground(incomingCall));
                    },
                  ),
                ],
              ),
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
            ],
          ),
        ),
      ),
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
