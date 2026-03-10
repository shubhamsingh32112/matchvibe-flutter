import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../controllers/call_connection_controller.dart';
import '../providers/call_billing_provider.dart';
import '../services/permission_service.dart';
import '../services/security_service.dart';
import '../utils/call_remote_image_resolver.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/coin_purchase_popup.dart';
import '../../../shared/widgets/gem_icon.dart';

/// Screen for active video call — **pure renderer**.
///
/// Does NOT call join, does NOT inspect `activeCall`, does NOT manage
/// timers for readiness.  ONLY reacts to [CallConnectionPhase].
///
/// Shows an **outgoing call** screen during `preparing` / `joining` (for users)
/// or a **connecting** screen (for creators), then switches to the live video
/// call content on `connected`.
///
/// On `idle` / `disconnecting`, navigates to `/home`.
class VideoCallScreen extends ConsumerStatefulWidget {
  const VideoCallScreen({super.key});

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  @override
  void initState() {
    super.initState();
    // Keep the screen on for the entire duration of the call screen
    WakelockPlus.enable();
    debugPrint('🔆 [WAKELOCK] Screen wake lock ENABLED (call screen opened)');
  }

  @override
  void dispose() {
    // Release the wake lock when leaving the call screen
    WakelockPlus.disable();
    debugPrint('🔅 [WAKELOCK] Screen wake lock DISABLED (call screen closed)');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callConnectionControllerProvider);

    // 🔥 BACK BUTTON HANDLER: Intercept back button to end call
    // When user/creator taps back button during active call, end call for both parties
    Widget buildContent() {
      switch (callState.phase) {
        case CallConnectionPhase.preparing:
        case CallConnectionPhase.joining:
          return _OutgoingCallView(
            isOutgoing: callState.isOutgoing,
            call: callState.call,
          );

        case CallConnectionPhase.connected:
          return _VideoCallScreenContent(call: callState.call!);

        case CallConnectionPhase.failed:
          return _CallFailedView(
              error: callState.error, isOutgoing: callState.isOutgoing);

        case CallConnectionPhase.idle:
        case CallConnectionPhase.disconnecting:
          // Call ended — navigate to home (handled by controller via GoRouter)
          // This is a fallback in case the widget is still mounted
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go('/home');
            }
          });
          return const SizedBox.shrink();
      }
    }

    // Wrap with PopScope to intercept back button
    return PopScope(
      canPop: callState.phase == CallConnectionPhase.idle || 
              callState.phase == CallConnectionPhase.disconnecting,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          // Back button pressed - end call if active
          final phase = callState.phase;
          if (phase != CallConnectionPhase.idle && 
              phase != CallConnectionPhase.disconnecting) {
            debugPrint('🔙 [CALL] Back button pressed - ending call');
            await ref.read(callConnectionControllerProvider.notifier).endCall();
          }
        }
      },
      child: buildContent(),
    );
  }
}

// ---------------------------------------------------------------------------
// Outgoing / Connecting call view
// ---------------------------------------------------------------------------

/// Shown while the call is being set up (preparing / joining).
///
/// For users (outgoing): "Calling…" with a pulsating avatar and end-call button.
/// For creators (incoming-accepted): "Connecting…" with a spinner.
class _OutgoingCallView extends ConsumerStatefulWidget {
  final bool isOutgoing;
  final Call? call;

  const _OutgoingCallView({
    required this.isOutgoing,
    required this.call,
  });

  @override
  ConsumerState<_OutgoingCallView> createState() => _OutgoingCallViewState();
}

class _OutgoingCallViewState extends ConsumerState<_OutgoingCallView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusText = widget.isOutgoing ? 'Calling…' : 'Connecting…';
    final currentUserId = ref.watch(authProvider).firebaseUser?.uid;
    final callConnectionState = ref.watch(callConnectionControllerProvider);
    final remoteImageUrl = resolveRemoteImageUrl(
      call: widget.call,
      currentUserId: currentUserId,
      fallbackImageUrl: callConnectionState.remoteImageFallbackUrl,
      enableDebugLogs: true,
      debugSourceTag: 'outgoing',
    );

    // 🔥 BACK BUTTON HANDLER: End call when back button pressed during preparing/joining
    return PopScope(
      canPop: false, // Prevent default navigation
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          // Back button pressed - cancel/end call
          final phase = callConnectionState.phase;
          if (phase == CallConnectionPhase.preparing || 
              phase == CallConnectionPhase.joining) {
            debugPrint('🔙 [CALL] Back button pressed during $phase - ending call');
            await ref.read(callConnectionControllerProvider.notifier).endCall();
          }
        }
      },
      child: Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (remoteImageUrl != null)
            Image.network(
              remoteImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: scheme.surface),
            ),
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
            child: Column(
              children: [
                const Spacer(flex: 2),

                // ── Pulsating avatar ──────────────────────────────────────
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: remoteImageUrl != null
                          ? Image.network(
                              remoteImageUrl,
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
                ),

                const SizedBox(height: 32),

                // ── Status text ──────────────────────────────────────────
                Text(
                  statusText,
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
                const SizedBox(height: 16),

                // ── Animated dots ────────────────────────────────────────
                const _AnimatedDots(color: Colors.white),

                const Spacer(flex: 3),

                // ── End call button ──────────────────────────────────────
                GestureDetector(
                  onTap: () {
                    ref
                        .read(callConnectionControllerProvider.notifier)
                        .endCall();
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red,
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.call_end,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.isOutgoing ? 'Cancel' : 'End',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white70,
                      ),
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Three animated dots that pulse in sequence.
class _AnimatedDots extends StatefulWidget {
  final Color color;
  const _AnimatedDots({required this.color});

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final t = (_controller.value - delay).clamp(0.0, 1.0);
            final opacity = 0.3 + 0.7 * math.sin(t * math.pi);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Failed view
// ---------------------------------------------------------------------------

class _CallFailedView extends ConsumerWidget {
  final String? error;
  final bool isOutgoing;
  const _CallFailedView({this.error, this.isOutgoing = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callConnectionControllerProvider);
    final reason = callState.failureReason;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                reason == CallFailureReason.permissionDenied
                    ? Icons.no_photography_outlined
                    : Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _titleForReason(reason),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              const SizedBox(height: 24),
              // Primary action — context-dependent
              if (reason == CallFailureReason.permissionDenied)
                FilledButton.icon(
                  onPressed: () {
                    PermissionService.openAppSettings();
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                )
              else if (reason == CallFailureReason.joinTimeout ||
                  reason == CallFailureReason.sfuFailure ||
                  reason == CallFailureReason.unknown)
                FilledButton.icon(
                  onPressed: () {
                    // endCall resets to idle → screen pops → user can retry
                    ref
                        .read(callConnectionControllerProvider.notifier)
                        .endCall();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              const SizedBox(height: 12),
              // Always show Go Back
              TextButton.icon(
                onPressed: () {
                  ref
                      .read(callConnectionControllerProvider.notifier)
                      .endCall();
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _titleForReason(CallFailureReason? reason) {
    switch (reason) {
      case CallFailureReason.permissionDenied:
        return 'Permissions Required';
      case CallFailureReason.joinTimeout:
        return 'Connection Timed Out';
      case CallFailureReason.creatorNotPickedUp:
        return 'Creator Didn\'t Pick Up'; // Unused — we show toast on home instead
      case CallFailureReason.rejected:
        return 'Call Declined';
      case CallFailureReason.sfuFailure:
        return 'Connection Error';
      case CallFailureReason.unknown:
      case null:
        return 'Call Failed';
    }
  }
}

// ---------------------------------------------------------------------------
// Connected content (preserves security & max-participant checks)
// ---------------------------------------------------------------------------

/// Internal stateful widget for call screen content.
///
/// Mounted ONLY when `phase == connected`.
class _VideoCallScreenContent extends ConsumerStatefulWidget {
  final Call call;
  const _VideoCallScreenContent({required this.call});

  @override
  ConsumerState<_VideoCallScreenContent> createState() =>
      _VideoCallScreenContentState();
}

class _VideoCallScreenContentState
    extends ConsumerState<_VideoCallScreenContent> {
  bool _isScreenCaptured = false;
  bool _forceEndDialogShown = false;
  StreamSubscription<int>? _participantsSubscription;

  @override
  void initState() {
    super.initState();
    _setupSecurity();
    _listenForParticipants();
  }

  @override
  void dispose() {
    _participantsSubscription?.cancel();
    SecurityService.clearOnScreenCaptureChanged();
    super.dispose();
  }

  // ──── Phase 4: partial-state optimisation ────

  /// Listen only to participant-count changes via [Call.partialState].
  /// Ignores audio/video churn — only reacts when count > 2.
  void _listenForParticipants() {
    _participantsSubscription = widget.call
        .partialState((s) => s.callParticipants.length)
        .listen((count) {
      if (count > 2) {
        debugPrint(
            '🚨 [CALL] Max participants exceeded: $count (max: 2)');
        debugPrint('   Leaving call immediately for security');
        _handleMaxParticipantsExceeded();
      }
    });
  }

  // ──── Max participants enforcement (double lock) ────

  /// Phase 4: Defense in depth — check participant count client-side.
  /// If participantCount > 2, immediately leave call.
  Future<void> _handleMaxParticipantsExceeded() async {
    try {
      debugPrint(
          '❌ [CALL] SECURITY VIOLATION: More than 2 participants detected');
      ref.read(callConnectionControllerProvider.notifier).endCall();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call ended: Maximum participants exceeded'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [CALL] Error handling max participants: $e');
    }
  }

  // ──── Security (Phase 6) ────

  /// Register call-level reaction to app-wide screen capture detection.
  void _setupSecurity() {
    SecurityService.setOnScreenCaptureChanged((isCaptured) {
      if (mounted) {
        setState(() {
          _isScreenCaptured = isCaptured;
        });

        if (isCaptured) {
          debugPrint(
              '🚫 [SECURITY] Screen recording detected — disconnecting call');
          _handleScreenCaptureDetected();
        }
      }
    });
  }

  /// Handle screen capture detection (iOS).
  /// Disconnects call when screen recording starts.
  Future<void> _handleScreenCaptureDetected() async {
    try {
      ref.read(callConnectionControllerProvider.notifier).endCall();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call ended: Screen recording detected'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [SECURITY] Error handling screen capture: $e');
    }
  }

  // ──── Build ────

  @override
  Widget build(BuildContext context) {
    final billingState = ref.watch(callBillingProvider);
    final authState = ref.watch(authProvider);
    final callConnectionState = ref.watch(callConnectionControllerProvider);
    final materialTheme = Theme.of(context);
    final baseStreamTheme = materialTheme.extension<StreamVideoTheme>() ??
        StreamVideoTheme.fromTheme(materialTheme);
    final transparentCallContentTheme = baseStreamTheme.copyWith(
      callContentTheme: baseStreamTheme.callContentTheme.copyWith(
        callContentBackgroundColor: Colors.transparent,
      ),
    );
    final currentUserId = authState.firebaseUser?.uid;
    final remoteImageUrl = resolveRemoteImageUrl(
      call: widget.call,
      currentUserId: currentUserId,
      fallbackImageUrl: callConnectionState.remoteImageFallbackUrl,
      enableDebugLogs: true,
      debugSourceTag: 'connected',
    );
    final isCreator =
        authState.user?.role == 'creator' || authState.user?.role == 'admin';

    // ── Force-end handling ──────────────────────────────────────────
    ref.listen<CallBillingState>(callBillingProvider, (prev, next) {
      if (next.forceEnded && !_forceEndDialogShown) {
        _forceEndDialogShown = true;
        // End the call first
        ref.read(callConnectionControllerProvider.notifier).endCall();
        // Show buy-more dialog after a short delay
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showOutOfCoinsDialog(context);
          }
        });
      }
    });

    // 🔥 BACK BUTTON HANDLER: End call when back button pressed during connected phase
    return PopScope(
      canPop: false, // Prevent default navigation
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          // Back button pressed - end call for both parties
          final phase = callConnectionState.phase;
          if (phase == CallConnectionPhase.connected) {
            debugPrint('🔙 [CALL] Back button pressed during connected call - ending call for both parties');
            await ref.read(callConnectionControllerProvider.notifier).endCall();
          }
        }
      },
      child: Scaffold(
      body: Stack(
        children: [
          if (remoteImageUrl != null)
            Positioned.fill(
              child: Image.network(
                remoteImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: Colors.black),
              ),
            )
          else
            const Positioned.fill(
              child: ColoredBox(color: Colors.black),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
          ),
          Theme(
            data: materialTheme.copyWith(
              extensions: <ThemeExtension<dynamic>>[
                transparentCallContentTheme,
              ],
            ),
            child: StreamCallContainer(
              call: widget.call,
              callConnectOptions: CallConnectOptions(
                camera: TrackOption.enabled(),
                microphone: TrackOption.enabled(),
                screenShare: TrackOption.disabled(),
              ),
              onCallDisconnected: (CallDisconnectedProperties properties) {
                debugPrint('📞 [CALL] Call disconnected');
                debugPrint('   Reason: ${properties.reason}');
                ref
                    .read(callConnectionControllerProvider.notifier)
                    .endCall();
              },
            ),
          ),

          // ── Billing overlay (top of screen, below call controls) ────
          if (billingState.isActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 48,
              left: 16,
              right: 16,
              child: _BillingOverlay(
                billingState: billingState,
                isCreator: isCreator,
              ),
            ),

          // Show overlay if screen capture detected (iOS)
          if (_isScreenCaptured)
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.security, size: 64, color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Screen recording detected',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Call will be disconnected',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  void _showOutOfCoinsDialog(BuildContext context) {
    ref.read(callBillingProvider.notifier).reset();
    ref.read(authProvider.notifier).refreshUser();
    // Show coin purchase pop-up as bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CoinPurchaseBottomSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// Billing overlay widget
// ---------------------------------------------------------------------------

class _BillingOverlay extends StatelessWidget {
  final CallBillingState billingState;
  final bool isCreator;

  const _BillingOverlay({
    required this.billingState,
    required this.isCreator,
  });

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Timer
          Row(
            children: [
              const Icon(Icons.timer, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                _formatDuration(billingState.accurateElapsedSeconds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          // Coins / Earnings
          if (isCreator)
            Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.greenAccent, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${billingState.creatorEarnings.truncateToDouble() == billingState.creatorEarnings ? billingState.creatorEarnings.toInt() : billingState.creatorEarnings.toStringAsFixed(1)} coins',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                GemIcon(
                  color: billingState.remainingSeconds < 30
                      ? Colors.redAccent
                      : Colors.amber,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '${billingState.userCoins}',
                  style: TextStyle(
                    color: billingState.remainingSeconds < 30
                        ? Colors.redAccent
                        : Colors.amber,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                // Remaining time
                Text(
                  '(${_formatDuration(billingState.remainingSeconds)})',
                  style: TextStyle(
                    color: billingState.remainingSeconds < 30
                        ? Colors.redAccent.withValues(alpha: 0.8)
                        : Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
