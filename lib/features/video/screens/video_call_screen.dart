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
import '../utils/call_overlay_rules.dart';
import '../widgets/call_dial_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/images/image_cache_managers.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/providers/coin_purchase_popup_provider.dart';
import '../../wallet/providers/wallet_pricing_provider.dart';

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
  /// Cache budget while a video call is active. Memory pressure during a
  /// call kills the renderer first, so we voluntarily shed image cache.
  static const int _callCacheBudgetBytes = 80 << 20;

  int? _stashedImageCacheBytes;

  Widget _buildTransitionView() {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Keep the screen on for the entire duration of the call screen
    WakelockPlus.enable();
    debugPrint('🔆 [WAKELOCK] Screen wake lock ENABLED (call screen opened)');

    // Shrink the image cache budget for the lifetime of this screen so the
    // video renderer has more headroom on mid-range devices.
    final cache = PaintingBinding.instance.imageCache;
    _stashedImageCacheBytes = cache.maximumSizeBytes;
    if (cache.maximumSizeBytes > _callCacheBudgetBytes) {
      cache.maximumSizeBytes = _callCacheBudgetBytes;
    }
  }

  @override
  void dispose() {
    // Restore the image cache budget BEFORE other dispose work.
    final cache = PaintingBinding.instance.imageCache;
    final stashed = _stashedImageCacheBytes;
    if (stashed != null) {
      cache.maximumSizeBytes = stashed;
      _stashedImageCacheBytes = null;
    }

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
            error: callState.error,
            isOutgoing: callState.isOutgoing,
          );

        case CallConnectionPhase.idle:
          // Call ended — navigate to home (handled by controller via GoRouter)
          // This is a fallback in case the widget is still mounted
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go('/home');
            }
          });
          return _buildTransitionView();
        case CallConnectionPhase.disconnecting:
          return _buildTransitionView();
      }
    }

    // Wrap with PopScope to intercept back button
    return PopScope(
      canPop:
          callState.phase == CallConnectionPhase.idle ||
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

  const _OutgoingCallView({required this.isOutgoing, required this.call});

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
    final currentUserId = ref.watch(authProvider).firebaseUser?.uid;
    final callConnectionState = ref.watch(callConnectionControllerProvider);
    final isConnecting =
        !widget.isOutgoing || callConnectionState.creatorAcceptedForOutgoing;
    final statusText = isConnecting ? 'Connecting...' : 'Awaiting response...';
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
              '🔙 [CALL] Back button pressed during $phase - ending call',
            );
            await ref.read(callConnectionControllerProvider.notifier).endCall();
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black54,
        body: SafeArea(
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
                    statusText: statusText,
                    showConnectingBar: isConnecting,
                    connectingBarAnimation: _barController,
                    onHangUp: () {
                      ref.read(callConnectionControllerProvider.notifier).endCall();
                    },
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  ),
                ),
              ),
              const Expanded(child: SizedBox.shrink()),
            ],
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
        : UserMessageMapper.fromString(error!, fallback: 'Please try again.');

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
                  ref.read(callConnectionControllerProvider.notifier).endCall();
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
  bool _durationLimitHandled = false;
  String? _lastHandledForceEndCallId;
  bool _loggedHeartbeatLast10 = false;
  bool _loggedSecurityOverlay = false;
  bool _loggedBillingSyncHint = false;
  bool _loggedBillingConnectionIssue = false;
  DateTime _connectedMountedAt = DateTime.now();
  DateTime? _lastScreenCaptureSignalAt;
  StreamSubscription<int>? _participantsSubscription;
  Timer? _durationLimitTimer;

  @override
  void initState() {
    super.initState();
    _connectedMountedAt = DateTime.now();
    _setupSecurity();
    _listenForParticipants();
    _startDurationLimitWatchdog();
  }

  @override
  void dispose() {
    _participantsSubscription?.cancel();
    _durationLimitTimer?.cancel();
    SecurityService.clearOnScreenCaptureChanged();
    super.dispose();
  }

  void _startDurationLimitWatchdog() {
    _durationLimitTimer?.cancel();
    final billing = ref.read(callBillingProvider);
    final limit = billing.durationLimit;
    final startMs = billing.callStartTimeMs;
    if (limit == null || limit <= 0 || startMs == null) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsed = ((nowMs - startMs) / 1000).floor();
    final remaining = (limit - elapsed).clamp(0, limit);
    _durationLimitTimer = Timer(Duration(seconds: remaining), () {
      _enforceDurationLimitIfNeeded();
    });
  }

  void _enforceDurationLimitIfNeeded() {
    if (_durationLimitHandled) return;
    final billing = ref.read(callBillingProvider);
    final limit = billing.durationLimit;
    final startMs = billing.callStartTimeMs;
    if (limit == null || limit <= 0 || startMs == null) return;

    final elapsedSeconds =
        ((DateTime.now().millisecondsSinceEpoch - startMs) / 1000).floor();
    if (elapsedSeconds < limit) return;

    _durationLimitHandled = true;
    debugPrint(
      '⏱️ [CALL] Local duration watchdog reached ${elapsedSeconds}s (limit: ${limit}s) — ending call',
    );
    ref.read(callConnectionControllerProvider.notifier).endCall();
  }

  // ──── Phase 4: partial-state optimisation ────

  /// Listen only to participant-count changes via [Call.partialState].
  /// Ignores audio/video churn — only reacts when count > 2.
  void _listenForParticipants() {
    _participantsSubscription = widget.call
        .partialState((s) => s.callParticipants.length)
        .listen((count) {
          if (count > 2) {
            debugPrint('🚨 [CALL] Max participants exceeded: $count (max: 2)');
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
        '❌ [CALL] SECURITY VIOLATION: More than 2 participants detected',
      );
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
      if (!mounted) return;
      if (_isScreenCaptured == isCaptured) return;
      final now = DateTime.now();
      final lastSignal = _lastScreenCaptureSignalAt;
      if (lastSignal != null &&
          now.difference(lastSignal) < const Duration(milliseconds: 300)) {
        return;
      }
      _lastScreenCaptureSignalAt = now;

      setState(() {
        _isScreenCaptured = isCaptured;
      });

      if (isCaptured) {
        debugPrint(
          '🚫 [SECURITY] Screen recording detected — disconnecting call',
        );
        _handleScreenCaptureDetected();
      }
    });
  }

  /// Handle screen capture detection (iOS).
  /// Disconnects call when screen recording starts.
  Future<void> _handleScreenCaptureDetected() async {
    try {
      ref.read(callConnectionControllerProvider.notifier).endCall();

      if (mounted) {
        AppToast.showError(context, 'Call ended: screen recording detected');
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
    final baseStreamTheme =
        materialTheme.extension<StreamVideoTheme>() ??
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
    final showBillingOverlay =
        callConnectionState.phase == CallConnectionPhase.connected;
    final connectedFor =
        DateTime.now().difference(_connectedMountedAt);
    final showBillingConnectionIssue =
        CallOverlayPolicy.shouldShowBillingConnectionIssue(
      isConnected: callConnectionState.phase == CallConnectionPhase.connected,
      billing: billingState,
      connectedFor: connectedFor,
    );
    final showBillingSyncing = !showBillingConnectionIssue &&
        CallOverlayPolicy.shouldShowBillingSyncHint(
      isConnected: callConnectionState.phase == CallConnectionPhase.connected,
      billing: billingState,
      connectedFor: connectedFor,
    );
    final showHeartbeatBorder = shouldShowLastTenSecondsHeartbeat(
      isCreator: isCreator,
      billing: billingState,
    );
    if (!showHeartbeatBorder) {
      _loggedHeartbeatLast10 = false;
    } else if (!_loggedHeartbeatLast10) {
      _loggedHeartbeatLast10 = true;
      debugPrint(
        '📉 [CALL_OVERLAY] heartbeat_last_10s_shown callId=${billingState.callId} remainingSeconds=${billingState.remainingSeconds}',
      );
    }
    final showSecurityBlock = CallOverlayPolicy.shouldShowSecurityBlock(
      isScreenCaptured: _isScreenCaptured,
    );

    if (!showSecurityBlock) {
      _loggedSecurityOverlay = false;
    } else if (!_loggedSecurityOverlay) {
      _loggedSecurityOverlay = true;
      debugPrint(
        '🔒 [CALL_OVERLAY] security_overlay_shown callId=${billingState.callId}',
      );
    }
    if (!showBillingSyncing) {
      _loggedBillingSyncHint = false;
    } else if (!_loggedBillingSyncHint) {
      _loggedBillingSyncHint = true;
      debugPrint(
        '🧾 [CALL_OVERLAY] overlay_shown type=billing_sync_hint callId=${billingState.callId} phase=${callConnectionState.phase}',
      );
    }
    if (showBillingConnectionIssue && !_loggedBillingConnectionIssue) {
      _loggedBillingConnectionIssue = true;
      debugPrint(
        '🧾 [CALL_OVERLAY] overlay_shown type=billing_connection_issue callId=${billingState.callId} connectedFor=${connectedFor.inMilliseconds}ms',
      );
    } else if (!showBillingConnectionIssue) {
      _loggedBillingConnectionIssue = false;
    }

    // Pointer probe: if this log stops appearing when the gray scrim is visible,
    // it's strong evidence a route-level ModalBarrier is intercepting taps.
    void logPointerDown() {
      debugPrint(
        '🖱️ [CALL_OVERLAY] pointer_down '
        'phase=${callConnectionState.phase.name} '
        'callId=${billingState.callId} '
        'remainingSeconds=${billingState.remainingSeconds} '
        'showHeartbeatBorder=$showHeartbeatBorder '
        'showBillingSyncHint=$showBillingSyncing '
        'showBillingConnectionIssue=$showBillingConnectionIssue',
      );
    }

    // ── Force-end handling (billing is server-driven; UI only reacts) ──
    ref.listen<CallBillingState>(callBillingProvider, (prev, next) {
      if ((prev?.isActive != true && next.isActive) ||
          (prev?.callStartTimeMs == null && next.callStartTimeMs != null)) {
        final ms = DateTime.now().difference(_connectedMountedAt).inMilliseconds;
        debugPrint(
          '🧾 [CALL_OVERLAY] billing_sync_hint_resolved_after_ms=$ms callId=${next.callId}',
        );
      }
      final prevStart = prev?.callStartTimeMs;
      final prevLimit = prev?.durationLimit;
      if (next.callStartTimeMs != prevStart ||
          next.durationLimit != prevLimit) {
        _startDurationLimitWatchdog();
      }
      if (next.forceEnded && !_forceEndDialogShown) {
        final forceEndCallId = next.callId;
        if (forceEndCallId != null &&
            forceEndCallId == _lastHandledForceEndCallId) {
          return;
        }
        _lastHandledForceEndCallId = forceEndCallId;
        _forceEndDialogShown = true;
        debugPrint(
          '🚨 [CALL_OVERLAY] force_end_prompt_shown callId=${next.callId} reason=${next.forceEndReason}',
        );
        ref.read(callConnectionControllerProvider.notifier).endCall();
        final role = ref.read(authProvider).user?.role;
        final showPurchase = role != 'creator' && role != 'admin';
        if (showPurchase) {
          ref.read(callBillingProvider.notifier).reset();
          final currentUid = ref.read(authProvider).firebaseUser?.uid;
          final cc = ref.read(callConnectionControllerProvider);
          final remoteUid = resolveRemoteParticipantFirebaseUid(
            call: widget.call,
            currentUserId: currentUid,
          );
          final display = resolveRemoteParticipantDisplay(
            call: widget.call,
            currentUserId: currentUid,
            fallbackName: 'Creator',
          );
          final photo = resolveRemoteImageUrl(
            call: widget.call,
            currentUserId: currentUid,
            fallbackImageUrl: cc.remoteImageFallbackUrl,
          );
          final forceEndCallId = next.callId;
          unawaited(() async {
            await ref.read(authProvider.notifier).refreshUser();
            await prefetchWalletPricing(ref, forceRefresh: true);
            ref.read(coinPurchasePopupProvider.notifier).state = CoinPopupIntent(
              reason: 'force_end_out_of_coins',
              dedupeKey: 'coin-force-end-${forceEndCallId ?? 'unknown'}',
              remoteDisplayName: display.primaryName,
              remotePhotoUrl: photo,
              remoteFirebaseUid: remoteUid,
            );
          }());
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
            debugPrint(
              '🔙 [CALL] Back button pressed during connected call - ending call for both parties',
            );
            await ref.read(callConnectionControllerProvider.notifier).endCall();
          }
        }
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => logPointerDown(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
            if (remoteImageUrl != null)
              Positioned.fill(
                child: AppNetworkImage(
                  imageUrl: remoteImageUrl,
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  fit: BoxFit.cover,
                  cacheManager: avatarCacheManager,
                  errorFallback: const ColoredBox(color: Colors.black),
                  variantTag: 'callBg',
                ),
              )
            else
              const Positioned.fill(child: ColoredBox(color: Colors.black)),
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
                  ref.read(callConnectionControllerProvider.notifier).endCall();
                },
              ),
            ),

            if (showBillingOverlay)
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
                      showSyncingHint: showBillingSyncing,
                      showBillingConnectionIssue: showBillingConnectionIssue,
                    ),
                  ),
                ),
              ),

            // Show heartbeat warning for true last 10 seconds.
            if (showHeartbeatBorder)
              const _LowBalanceHeartbeatBorder(),

            // Policy-managed security overlay.
            if (showSecurityBlock)
              ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.security,
                        size: 64,
                        color: materialTheme.colorScheme.primary,
                      ),
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
      ),
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
