import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../controllers/call_connection_controller.dart';
import '../providers/call_billing_provider.dart';
import '../widgets/live_billing_overlay.dart';
import '../services/permission_service.dart';
import '../services/security_service.dart';
import '../utils/call_remote_image_resolver.dart';
import '../utils/call_remote_participant_display.dart';
import '../widgets/call_dial_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/coin_purchase_popup.dart';
import '../../../shared/widgets/app_modal_bottom_sheet.dart';

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
          if (callState.isOutgoing) {
            // Outgoing dial UI is the root [OutgoingCallOverlay]; this route is
            // only used before first frame or in edge cases.
            return const Scaffold(body: SizedBox.shrink());
          }
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

/// Shown while the call is being set up (preparing / joining) on `/call`
/// (e.g. creator after accept). Uses the same [CallDialCard] as dial / incoming.
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
    final statusText = widget.isOutgoing ? 'Calling…' : 'Connecting…';
    final currentUserId = ref.watch(authProvider).firebaseUser?.uid;
    final callConnectionState = ref.watch(callConnectionControllerProvider);
    final remoteUrl = resolveRemoteImageUrl(
      call: widget.call,
      currentUserId: currentUserId,
      fallbackImageUrl: callConnectionState.remoteImageFallbackUrl,
      enableDebugLogs: true,
      debugSourceTag: 'outgoing',
    );
    final String? photoUrl = remoteUrl != null && remoteUrl.trim().isNotEmpty
        ? remoteUrl.trim()
        : null;

    final display = resolveRemoteParticipantDisplay(
      call: widget.call,
      currentUserId: currentUserId,
      fallbackName: widget.isOutgoing ? 'Creator' : 'User',
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final phase = callConnectionState.phase;
          if (phase == CallConnectionPhase.preparing ||
              phase == CallConnectionPhase.joining) {
            debugPrint(
                '🔙 [CALL] Back button pressed during $phase - ending call');
            await ref.read(callConnectionControllerProvider.notifier).endCall();
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black54,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
                child: CallDialCard(
                  nameLine: display.nameLine,
                  country: display.country,
                  imageUrl: photoUrl,
                  statusText: statusText,
                  showConnectingBar: true,
                  connectingBarAnimation: _barController,
                  onHangUp: () {
                    ref
                        .read(callConnectionControllerProvider.notifier)
                        .endCall();
                  },
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                ),
              ),
            ),
          ),
        ),
      ),
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
    final safeDetail = error == null
        ? null
        : UserMessageMapper.fromString(
            error!,
            fallback: 'Please try again.',
          );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _titleForReason(reason),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (safeDetail != null) ...[
                const SizedBox(height: 8),
                Text(
                  safeDetail,
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
        AppToast.showError(
          context,
          'Call ended: maximum participants exceeded',
          duration: const Duration(seconds: 5),
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
        AppToast.showError(
          context,
          'Call ended: screen recording detected',
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

    // ── Force-end handling (billing is server-driven; UI only reacts) ──
    ref.listen<CallBillingState>(callBillingProvider, (prev, next) {
      if (next.forceEnded && !_forceEndDialogShown) {
        _forceEndDialogShown = true;
        ref.read(callConnectionControllerProvider.notifier).endCall();
        final role = ref.read(authProvider).user?.role;
        final showPurchase =
            role != 'creator' && role != 'admin';
        if (showPurchase) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showOutOfCoinsDialog(context);
            }
          });
        }
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

          if (billingState.isActive)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                minimum: const EdgeInsets.only(top: 8, left: 12, right: 12),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: LiveBillingOverlay(
                    billing: billingState,
                    isCreator: isCreator,
                  ),
                ),
              ),
            ),

          // Server `billing:update` coins — show when balance is 10 or below (still in call).
          if (!isCreator &&
              billingState.isActive &&
              billingState.userCoins > 0 &&
              billingState.userCoins <= 10)
            _LowBalanceHeartbeatBorder(),

          // Show overlay if screen capture detected (iOS)
          if (_isScreenCaptured)
            ColoredBox(
              color: materialTheme.colorScheme.surface.withValues(alpha: 0.97),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.security,
                        size: 64, color: materialTheme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Screen recording detected',
                      style: TextStyle(
                        color: materialTheme.colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Call will be disconnected',
                      style: TextStyle(
                        color: materialTheme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
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
    showAppModalBottomSheet(
      context: context,
      builder: (context) => const CoinPurchaseBottomSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// Low balance — 8px red border with heartbeat (user only; parent gates visibility)
// ---------------------------------------------------------------------------

class _LowBalanceHeartbeatBorder extends StatefulWidget {
  const _LowBalanceHeartbeatBorder();

  @override
  State<_LowBalanceHeartbeatBorder> createState() =>
      _LowBalanceHeartbeatBorderState();
}

class _LowBalanceHeartbeatBorderState extends State<_LowBalanceHeartbeatBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_controller.value);
            final alpha = 0.36 + t * 0.48;
            return DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppPalette.primaryRed.withValues(alpha: alpha),
                  width: 8,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
