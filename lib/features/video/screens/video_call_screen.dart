import 'dart:async';
<<<<<<< HEAD
import 'dart:math' as math;
=======
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import '../controllers/call_connection_controller.dart';
import '../providers/call_billing_provider.dart';
import '../services/permission_service.dart';
import '../services/security_service.dart';
<<<<<<< HEAD
import '../../auth/providers/auth_provider.dart';

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
class VideoCallScreen extends ConsumerWidget {
  const VideoCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callConnectionControllerProvider);

    switch (callState.phase) {
      case CallConnectionPhase.preparing:
      case CallConnectionPhase.joining:
        return _OutgoingCallView(isOutgoing: callState.isOutgoing);

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
  const _OutgoingCallView({required this.isOutgoing});

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

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
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
                  color: scheme.primaryContainer,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.person,
                  size: 60,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Status text ──────────────────────────────────────────
            Text(
              statusText,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Video Call',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),

            // ── Animated dots ────────────────────────────────────────
            _AnimatedDots(color: scheme.primary),

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
                    color: scheme.onSurfaceVariant,
                  ),
            ),

            const SizedBox(height: 48),
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
=======
import '../services/call_service.dart';
import '../providers/stream_video_provider.dart';
import '../services/call_navigation_service.dart';
import '../../auth/providers/auth_provider.dart';

/// Screen for active video call
/// 
/// 🔥 CRITICAL: Reads call ONLY from StreamVideo.state.activeCall (single source of truth)
/// Router extras are NOT used - Stream state is authoritative
/// 
/// Uses StreamCallContainer with restrictions:
/// - Screen sharing disabled
/// - Recording disabled
/// - Broadcasting disabled
/// - Camera and microphone enabled
/// - Platform-level screenshot/recording blocking (Phase 6)
/// 🔥 FIX 4: Single call screen for both user and creator
/// No separate "accept screen" vs "call screen"
/// Incoming → navigate → loading → connected
class VideoCallScreen extends ConsumerStatefulWidget {
  const VideoCallScreen({super.key});

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  Timer? _timeoutTimer;
  bool _hasTimedOut = false;
  
  @override
  void initState() {
    super.initState();
    // 🔥 FIX 4: Add timeout for connecting state (15 seconds)
    // If activeCall isn't set within timeout, navigate back
    // This prevents infinite loading if something goes wrong
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) {
        final streamVideo = ref.read(streamVideoProvider);
        final call = streamVideo?.state.activeCall.valueOrNull;
        if (call == null) {
          debugPrint('⏱️ [CALL SCREEN] Timeout waiting for activeCall - exiting');
          setState(() {
            _hasTimedOut = true;
          });
          // Navigate back after showing timeout message
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && Navigator.canPop(context)) {
              CallNavigationService.onCallScreenExited();
              Navigator.pop(context);
            }
          });
        }
      }
    });
  }
  
  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 CRITICAL: Read call ONLY from StreamVideo.state.activeCall (single source of truth)
    // UI must be driven by activeCall, not by who initiated the call
    // This ensures the call screen renders for BOTH user AND creator
    final streamVideo = ref.watch(streamVideoProvider);
    final call = streamVideo?.state.activeCall.valueOrNull;

    if (call == null) {
      // 🔥 Show "Connecting..." screen while waiting for activeCall
      // This is the EXPECTED state right after navigation
      // Stream sets activeCall when join() starts or accept() completes
      // Timeout will fire after 15s if activeCall is never set
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_hasTimedOut) ...[
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  'Connection Failed',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Unable to connect to the call',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ] else ...[
                const CircularProgressIndicator(
                  color: Colors.white,
                ),
                const SizedBox(height: 24),
                Text(
                  'Connecting...',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Setting up your call',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    
    // 🔥 Call is available - cancel timeout and show call content
    _timeoutTimer?.cancel();
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed

  static String _titleForReason(CallFailureReason? reason) {
    switch (reason) {
      case CallFailureReason.permissionDenied:
        return 'Permissions Required';
      case CallFailureReason.joinTimeout:
        return 'Connection Timed Out';
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
<<<<<<< HEAD
  bool _forceEndDialogShown = false;
  StreamSubscription<int>? _participantsSubscription;
=======
  
  // PHASE 5: Visual timer state
  int _remainingCoins = 0;
  Timer? _coinTimer;
  bool _coinsExhausted = false;
  bool _timerStarted = false; // 🔥 FIX 3: Track if timer has started

  StreamSubscription? _callStateSubscription;
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed

  @override
  void initState() {
    super.initState();
    _setupSecurity();
<<<<<<< HEAD
    _listenForParticipants();
=======
    _checkMaxParticipants();
    
    // Get initial coins (don't start timer yet - wait for CallStatusConnected)
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user != null) {
      _remainingCoins = user.coins;
    }
    
    // 🔥 FIX 2 & 3: Drive UI from call.state stream, not async flow
    // Listen to call state changes and react accordingly
    _callStateSubscription = widget.call.state.listen((callState) {
      _checkMaxParticipants();
      
      final status = callState.status;
      
      // 🔥 FIX 3: Only start coin timer when media is CONNECTED (session_started)
      // Stream docs: CallStatusConnected = media flowing
      // Anything before that is signaling - don't bill yet
      if (status is CallStatusConnected && !_timerStarted) {
        debugPrint('💰 [CALL SCREEN] CallStatusConnected - starting coin timer NOW');
        _startCoinTimer();
      }
      
      // If call is disconnected, exit call screen
      if (status.isDisconnected) {
        debugPrint('📞 [CALL SCREEN] Call disconnected - exiting');
        if (mounted) {
          CallNavigationService.onCallScreenExited();
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        }
      }
    });
    
    // Also check current status in case we missed the Connected event
    final currentStatus = widget.call.state.valueOrNull?.status;
    if (currentStatus is CallStatusConnected && !_timerStarted) {
      debugPrint('💰 [CALL SCREEN] Already connected - starting coin timer');
      _startCoinTimer();
    }
  }
  
  
  /// 🔥 FIX 3: Start visual coin countdown timer ONLY when call is connected
  /// 
  /// This is visual only - backend is the source of truth for billing.
  /// Timer starts ONLY when CallStatusConnected (media flowing).
  /// Stream docs: "CallStatusConnected / session_started = media flowing"
  void _startCoinTimer() {
    if (_timerStarted) return; // Prevent double-start
    _timerStarted = true;
    
    debugPrint('💰 [CALL TIMER] Starting visual timer with $_remainingCoins coins');
    
    // Start timer that decrements every second
    _coinTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingCoins > 0) {
            _remainingCoins -= 1;
          } else {
            _coinsExhausted = true;
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
  }

  @override
  void dispose() {
<<<<<<< HEAD
    _participantsSubscription?.cancel();
=======
    // PHASE 5: Clean up timer
    _coinTimer?.cancel();
    // Clean up call state subscription
    _callStateSubscription?.cancel();
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
    // Disable security when leaving call screen
    SecurityService.disableCallSecurity();
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

  /// Setup platform-level security.
  /// Android: FLAG_SECURE  ·  iOS: screen capture detection
  Future<void> _setupSecurity() async {
    await SecurityService.enableCallSecurity();

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
<<<<<<< HEAD
    final billingState = ref.watch(callBillingProvider);
    final authState = ref.watch(authProvider);
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

=======
    final scheme = Theme.of(context).colorScheme;
    
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
    return Scaffold(
      body: Stack(
        children: [
          StreamCallContainer(
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
<<<<<<< HEAD

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

=======
          // PHASE 5: Visual coin countdown timer (top of screen)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: _buildCoinTimer(scheme),
          ),
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
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
          // PHASE 5: Show overlay if coins exhausted (waiting for backend disconnect)
          if (_coinsExhausted)
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      size: 64,
                      color: scheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your coins are over',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Buy more to continue',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Call will end shortly...',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  /// 🔥 FIX 3: Build visual coin countdown timer widget
  /// Shows "Connecting..." until CallStatusConnected, then shows timer
  Widget _buildCoinTimer(ColorScheme scheme) {
    // 🔥 FIX 3: Show connecting state until timer starts (CallStatusConnected)
    if (!_timerStarted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: scheme.outline.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Connecting...',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    
    // Format seconds as MM:SS
    final minutes = _remainingCoins ~/ 60;
    final seconds = _remainingCoins % 60;
    final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    
    // Color based on remaining coins
    Color timerColor;
    if (_remainingCoins > 60) {
      timerColor = scheme.primary;
    } else if (_remainingCoins > 10) {
      timerColor = Colors.orange; // Warning color for low coins
    } else {
      timerColor = scheme.error;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: timerColor.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet,
            color: timerColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            timeString,
            style: TextStyle(
              color: timerColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '($_remainingCoins coins)',
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

<<<<<<< HEAD
  void _showOutOfCoinsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.monetization_on, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('Out of Coins'),
          ],
        ),
        content: const Text(
          'Your coin balance ran out and the call was ended.\n\n'
          'Would you like to buy more coins to continue calling?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(callBillingProvider.notifier).reset();
              // Refresh user data to get final balance
              ref.read(authProvider.notifier).refreshUser();
            },
            child: const Text('Not Now'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(callBillingProvider.notifier).reset();
              ref.read(authProvider.notifier).refreshUser();
              // Navigate to wallet screen
              context.push('/wallet');
            },
            icon: const Icon(Icons.shopping_cart),
            label: const Text('Buy Coins'),
          ),
        ],
      ),
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
                _formatDuration(billingState.elapsedSeconds),
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
                  '${billingState.creatorEarnings.toStringAsFixed(1)} coins',
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
                Icon(
                  Icons.monetization_on,
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
=======
  /// Handle call disconnection (Phase 7)
  /// 
  /// Called when:
  /// - Either participant leaves
  /// - Network drops beyond retry limit
  /// - Creator rejects
  /// - PHASE 3: Coins exhausted (INSUFFICIENT_COINS_CALL)
  void _handleCallDisconnected(BuildContext context, DisconnectReason reason) {
    // PHASE 8: Handle standardized insufficient coins disconnect
    final reasonStr = reason.toString().toUpperCase();
    if (reasonStr.contains('INSUFFICIENT_COINS') || 
        reasonStr.contains('INSUFFICIENT_COINS_CALL')) {
      if (mounted) {
        // PHASE 8: Always show Buy Coins modal (never silently fail)
        _showBuyCoinsModal(context);
      }
    }
    
    // Mark call screen as exited
    CallNavigationService.onCallScreenExited();
    
    // Navigate back when call ends
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
  }
  
  /// PHASE 8: Show Buy Coins modal for insufficient coins
  void _showBuyCoinsModal(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.read(authProvider);
    final user = authState.user;
    final coins = user?.coins ?? 0;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: scheme.error),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Insufficient Coins'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your coins are over. Buy more to continue.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'You currently have $coins coins.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to wallet/buy coins screen
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Navigate to wallet to buy coins'),
                  backgroundColor: scheme.primaryContainer,
                ),
              );
            },
            child: const Text('Buy Coins'),
          ),
        ],
      ),
    );
  }
}
