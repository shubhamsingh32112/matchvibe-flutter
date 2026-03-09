import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import '../services/call_service.dart';
import '../services/permission_service.dart';
import '../services/call_navigation_service.dart';
import '../services/call_ringtone_service.dart';
import '../providers/stream_video_provider.dart';
import '../providers/call_billing_provider.dart';
import '../providers/call_feedback_prompt_provider.dart';
import '../providers/creator_busy_toast_provider.dart';
import '../utils/call_remote_image_resolver.dart';
import '../utils/remote_avatar_lookup.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/availability_provider.dart';
import '../../../shared/providers/coin_purchase_popup_provider.dart';

// ---------------------------------------------------------------------------
// Phase / Failure reason / State
// ---------------------------------------------------------------------------

/// Frontend-only orchestration state for the call lifecycle.
/// Independent of Stream SDK internals — this is the **single source of truth**
/// that drives all UI.
enum CallConnectionPhase {
  idle,           // no call
  preparing,      // permissions, accept, getOrCreate
  joining,        // call.join() in progress
  connected,      // CallStatusConnected — StreamCallContainer can mount
  disconnecting,  // leaving / cleaning up
  failed,         // error — show retry UI
}

/// Typed failure reasons so the UI can show the right recovery action.
enum CallFailureReason {
  permissionDenied,   // → "Open Settings"
  joinTimeout,       // → "Retry" (connection failed after creator accepted)
  creatorNotPickedUp, // → "Go Back" / "Try Again" (creator didn't answer in 15s)
  sfuFailure,        // → "Retry" / "Contact support"
  rejected,          // → "Go Back"
  unknown,           // → "Go Back" + "Retry"
}

/// Immutable state exposed by [CallConnectionController].
class CallConnectionState {
  final CallConnectionPhase phase;
  final Call? call;
  final String? error;
  final CallFailureReason? failureReason;
  final String? remoteImageFallbackUrl;

  /// `true` when the local user initiated the call (outgoing).
  /// `false` when the local user received the call (incoming / creator side).
  final bool isOutgoing;

  const CallConnectionState({
    required this.phase,
    this.call,
    this.error,
    this.failureReason,
    this.remoteImageFallbackUrl,
    this.isOutgoing = false,
  });

  const CallConnectionState.idle()
      : phase = CallConnectionPhase.idle,
        call = null,
        error = null,
        failureReason = null,
        remoteImageFallbackUrl = null,
        isOutgoing = false;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final callConnectionControllerProvider =
    StateNotifierProvider<CallConnectionController, CallConnectionState>(
  (ref) => CallConnectionController(ref),
);

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Orchestrates both **user** and **creator** call flows.
///
/// Owns the full lifecycle:
///   preparing (→ navigate to /call) → joining → connected → disconnecting → idle (→ /home)
///
/// Serialises every async step so that race conditions are impossible.
///
/// ⚠️  Navigation to `/call` happens at `preparing` (outgoing / connecting screen).
/// ⚠️  Navigation to `/home` happens when the call ends or disconnects.
class CallConnectionController extends StateNotifier<CallConnectionState> {
  final Ref _ref;
  StreamSubscription<CallStatus>? _statusSubscription;
  Timer? _watchdog;

  /// True when creator has accepted (status transitioned to Connecting).
  /// Used for two-phase watchdog: ring (15s) vs join (30s after accept).
  bool _creatorAccepted = false;

  // Billing metadata — set when a user starts a call
  String? _activeCallId;
  String? _activeCreatorFirebaseUid;
  String? _activeCreatorMongoId;
  String? _activeUserFirebaseUid; // For creator-initiated calls: the user who pays
  bool _wasConnected = false;

  CallConnectionController(this._ref)
      : super(const CallConnectionState.idle());

  // ──────────────────────────────────────────────────────────────────────────
  //  User flow
  // ──────────────────────────────────────────────────────────────────────────

  /// User taps **Call** on a creator card.
  ///
  /// Sequence:
  ///   preparing → navigate to /call (outgoing screen) → permissions
  ///   → getOrCreate → joining → join() → wait for [CallStatusConnected]
  ///   → connected.
  Future<void> startUserCall({
    required String creatorFirebaseUid,
    required String creatorMongoId,
    String? creatorImageUrl,
  }) async {
    // Allow retry from failed state
    if (state.phase != CallConnectionPhase.idle &&
        state.phase != CallConnectionPhase.failed) {
      debugPrint(
          '⚠️ [CALL CTRL] startUserCall ignored — phase: ${state.phase}');
      return;
    }

    // ── Pre-flight: check coin balance ─────────────────────────────
    // Prevent the confusing UX where the call connects then immediately
    // force-ends because the user has 0 coins.
    final preFlightAuth = _ref.read(authProvider);
    final userCoins = preFlightAuth.user?.coins ?? 0;
    if (userCoins <= 0) {
      debugPrint('⚠️ [CALL CTRL] startUserCall blocked — 0 coins');
      state = const CallConnectionState(
        phase: CallConnectionPhase.failed,
        error: 'You need coins to make a video call. Please add coins first.',
        failureReason: CallFailureReason.unknown,
        isOutgoing: true,
      );
      return; // Stay on current screen — don't navigate to /call
    }

    // ── Reset billing state from any previous call ─────────────────
    _ref.read(callBillingProvider.notifier).reset();
    _wasConnected = false;
    _creatorAccepted = false;

    // Outgoing call tone while dialing / connecting.
    CallRingtoneService.startOutgoingTone();
    state = CallConnectionState(
      phase: CallConnectionPhase.preparing,
      isOutgoing: true,
      remoteImageFallbackUrl: creatorImageUrl,
    );

    // Navigate to /call immediately so user sees the outgoing call screen
    CallNavigationService.navigateToCallScreen();

    try {
      // 1. Permissions
      final hasPerms =
          await PermissionService.ensurePermissions(video: true);
      if (!hasPerms) {
        CallRingtoneService.stop();
        state = const CallConnectionState(
          phase: CallConnectionPhase.failed,
          error:
              'Camera and microphone permissions are required for video calls',
          failureReason: CallFailureReason.permissionDenied,
          isOutgoing: true,
        );
        return;
      }

      // 2. Stream Video client
      final streamVideo = _ref.read(streamVideoProvider);
      if (streamVideo == null) {
        CallRingtoneService.stop();
        state = const CallConnectionState(
          phase: CallConnectionPhase.failed,
          error: 'Video service not available. Please try again later.',
          failureReason: CallFailureReason.unknown,
          isOutgoing: true,
        );
        return;
      }

      // 3. Current user
      final authState = _ref.read(authProvider);
      final firebaseUser = authState.firebaseUser;
      if (firebaseUser == null) {
        CallRingtoneService.stop();
        state = const CallConnectionState(
          phase: CallConnectionPhase.failed,
          error: 'User not authenticated',
          failureReason: CallFailureReason.unknown,
          isOutgoing: true,
        );
        return;
      }

      // 4. Best-effort billing socket reconnect (non-blocking).
      // Do NOT delay call setup on socket readiness; billing has HTTP fallback.
      final socketService = _ref.read(socketServiceProvider);
      if (!socketService.isConnected) {
        debugPrint(
            '🔌 [CALL CTRL] Billing socket NOT connected — reconnecting in background...');
        final token = await firebaseUser.getIdToken();
        if (token != null) {
          unawaited(socketService.ensureConnected(token).then(
                (connected) => debugPrint(
                    '🔌 [CALL CTRL] Socket ensureConnected result: $connected'),
              ));
        }
      } else {
        debugPrint('✅ [CALL CTRL] Billing socket already connected');
      }

      // 5. getOrCreate (creates call + rings creator)
      final callService = _ref.read(callServiceProvider);
      final call = await callService.initiateCall(
        creatorFirebaseUid: creatorFirebaseUid,
        currentUserFirebaseUid: firebaseUser.uid,
        creatorMongoId: creatorMongoId,
        streamVideo: streamVideo,
      );

      // Store billing metadata
      _activeCallId = call.id;
      _activeCreatorFirebaseUid = creatorFirebaseUid;
      _activeCreatorMongoId = creatorMongoId;

      // 5. Transition to joining (stay on /call screen — outgoing UI)
      state = CallConnectionState(
        phase: CallConnectionPhase.joining,
        call: call,
        isOutgoing: true,
        remoteImageFallbackUrl: creatorImageUrl,
      );
      _startWatchdog();
      _listenForConnected(call);

      callService.joinCall(call);
      debugPrint('✅ [CALL CTRL] call.join() fired (fire-and-forget)');
      // Actual UI transition → connected happens in _listenForConnected.
    } catch (e) {
      debugPrint('❌ [CALL CTRL] startUserCall error: $e');
      CallRingtoneService.stop();
      await _cleanupCall();
      if (mounted) {
        state = CallConnectionState(
          phase: CallConnectionPhase.failed,
          error: e.toString(),
          failureReason: CallFailureReason.sfuFailure,
          isOutgoing: true,
        );
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Creator flow
  // ──────────────────────────────────────────────────────────────────────────

  /// Creator taps **Accept** on the incoming call widget.
  ///
  /// Sequence:
  ///   preparing → navigate to /call (connecting screen) → permissions
  ///   → accept() → joining → join() → wait for [CallStatusConnected]
  ///   → connected.
  Future<void> acceptIncomingCall(Call call) async {
    // Allow retry from failed state
    if (state.phase != CallConnectionPhase.idle &&
        state.phase != CallConnectionPhase.failed) {
      debugPrint(
          '⚠️ [CALL CTRL] acceptIncomingCall ignored — phase: ${state.phase}');
      return;
    }

    // Reset billing state from any previous call
    _ref.read(callBillingProvider.notifier).reset();
    CallRingtoneService.stop();
    _wasConnected = false;
    final currentUserId = _ref.read(authProvider).firebaseUser?.uid;
    final initialFallbackImage = resolveRemoteImageUrl(
      call: call,
      currentUserId: currentUserId,
      enableDebugLogs: true,
      debugSourceTag: 'accept_incoming',
    );

    state = CallConnectionState(
      phase: CallConnectionPhase.preparing,
      remoteImageFallbackUrl: initialFallbackImage,
    );
    if (initialFallbackImage == null) {
      unawaited(_hydrateIncomingFallbackImage(call));
    }

    // Navigate to /call immediately so creator sees connecting screen
    CallNavigationService.navigateToCallScreen();

    try {
      // 1. Permissions
      final hasPerms =
          await PermissionService.ensurePermissions(video: true);
      if (!hasPerms) {
        state = const CallConnectionState(
          phase: CallConnectionPhase.failed,
          error:
              'Camera and microphone permissions are required for video calls',
          failureReason: CallFailureReason.permissionDenied,
        );
        return;
      }

      // 2. Ensure billing socket is connected (CRITICAL for creator-initiated calls).
      // For creator-initiated calls, the user needs to receive billing events.
      // We must await this to ensure the socket is ready before accepting the call.
      final socketService = _ref.read(socketServiceProvider);
      final firebaseUser = _ref.read(authProvider).firebaseUser;
      if (!socketService.isConnected && firebaseUser != null) {
        debugPrint(
            '🔌 [CALL CTRL] Billing socket NOT connected — connecting now...');
        final token = await firebaseUser.getIdToken();
        if (token != null) {
          final connected = await socketService.ensureConnected(token);
          debugPrint(
              '🔌 [CALL CTRL] Socket ensureConnected result: $connected');
          if (!connected) {
            debugPrint('⚠️ [CALL CTRL] Socket connection failed, but continuing...');
          }
        }
      } else {
        debugPrint('✅ [CALL CTRL] Billing socket already connected');
      }
      
      // Ensure billing provider is set up to listen for events
      _ref.read(callBillingProvider.notifier);

      // 3. Accept (tells Stream the callee accepted)
      await call.accept();
      debugPrint('✅ [CALL CTRL] call.accept() completed');

      // Store call ID so user can emit call:ended on disconnect.
      // Note: For creator-initiated calls, billing is triggered by creator's emitCallStarted,
      // but the user needs to track the call ID for proper cleanup.
      _activeCallId = call.id;

      // 3. Transition to joining
      state = CallConnectionState(
        phase: CallConnectionPhase.joining,
        call: call,
        remoteImageFallbackUrl: state.remoteImageFallbackUrl,
      );
      _startWatchdog();
      _listenForConnected(call);

      final callService = _ref.read(callServiceProvider);
      callService.joinCall(call);
      debugPrint('✅ [CALL CTRL] call.join() fired (fire-and-forget)');
      // Actual UI transition → connected happens in _listenForConnected.
    } catch (e) {
      debugPrint('❌ [CALL CTRL] acceptIncomingCall error: $e');
      CallRingtoneService.stop();
      await _cleanupCall();
      if (mounted) {
        state = CallConnectionState(
          phase: CallConnectionPhase.failed,
          error: e.toString(),
          failureReason: CallFailureReason.sfuFailure,
        );
      }
    }
  }


  Future<void> _hydrateIncomingFallbackImage(Call call) async {
    try {
      final dynamic callState = (call as dynamic).state?.value;
      final createdBy = callState?.createdBy;
      final remoteFirebaseUid = createdBy?.id?.toString() ??
          createdBy?.userId?.toString() ??
          extractCallerFirebaseUidFromCallId(call.id);
      final remoteUsername = createdBy?.name?.toString() ??
          createdBy?.extraData?['username']?.toString();

      final lookedUp = await lookupAvatarFromUserList(
        remoteFirebaseUid: remoteFirebaseUid,
        remoteUsername: remoteUsername,
        debugSourceTag: 'accept_incoming',
      );
      if (lookedUp == null || !mounted) return;

      final currentCallId = state.call?.id;
      final isSameCall = currentCallId == null || currentCallId == call.id;
      if (!isSameCall) return;
      if (state.remoteImageFallbackUrl == lookedUp) return;

      state = CallConnectionState(
        phase: state.phase,
        call: state.call,
        error: state.error,
        failureReason: state.failureReason,
        isOutgoing: state.isOutgoing,
        remoteImageFallbackUrl: lookedUp,
      );
    } catch (_) {
      // Best-effort fallback hydration only.
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  End / Leave
  // ──────────────────────────────────────────────────────────────────────────

  /// Ends the current call.
  ///
  /// Called by:
  /// - user tapping hang-up
  /// - disconnect event
  /// - max-participant violation
  /// - screen capture detection
  /// - "Go Back" on the failed view
  Future<void> endCall() async {
    if (state.phase == CallConnectionPhase.idle) return;
    CallRingtoneService.stop();

    final call = state.call;
    state = CallConnectionState(
        phase: CallConnectionPhase.disconnecting, call: call);

    _cancelSubscriptions(); // stop status listener first

    final endedCallId = _activeCallId;
    final endedCreatorFirebaseUid = _activeCreatorFirebaseUid;
    final endedCreatorLookupId = _activeCreatorMongoId;
    final wasConnected = _wasConnected;

    // ── Emit call:ended to trigger MongoDB settlement ──────────
    if (_activeCallId != null) {
      final socketService = _ref.read(socketServiceProvider);
      socketService.emitCallEnded(callId: _activeCallId!);
    }
    _activeCallId = null;
    _activeCreatorFirebaseUid = null;
    _activeCreatorMongoId = null;
    _activeUserFirebaseUid = null;
    _wasConnected = false;

    if (call != null) {
      try {
        await call.leave();
        debugPrint('✅ [CALL CTRL] call.leave() completed');
      } catch (e) {
        debugPrint('❌ [CALL CTRL] endCall leave error: $e');
      }
    }

    // Queue feedback prompt for the user who paid for the call
    // - User-initiated calls: wasOutgoing = true, _activeUserFirebaseUid = null (user pays)
    // - Creator-initiated calls: 
    //   * Creator's side: wasOutgoing = true, _activeUserFirebaseUid is set (user pays, but creator shouldn't rate)
    //   * User's side: wasOutgoing = false, _activeUserFirebaseUid = null (user pays, user should rate)
    // So we queue feedback if: wasConnected && we're NOT on creator's side of creator-initiated call
    // i.e., _activeUserFirebaseUid == null means we're the user who pays
    // Also ensure we're a regular user (not creator/admin) - only users should rate creators
    final authState = _ref.read(authProvider);
    final currentUser = authState.user;
    final isRegularUser = currentUser != null && currentUser.role == 'user';
    
    if (wasConnected &&
        _activeUserFirebaseUid == null &&
        isRegularUser &&
        endedCallId != null &&
        endedCallId.isNotEmpty) {
      _queuePostCallFeedbackPrompt(
        callId: endedCallId,
        creatorFirebaseUid: endedCreatorFirebaseUid,
        creatorLookupId: endedCreatorLookupId,
        call: call,
      );
    }

    // Navigate to home — both user and creator land on their home page
    CallNavigationService.navigateToHome();
    
    // Show coin pack bottom sheet after call ends (only for regular users)
    if (wasConnected && isRegularUser && mounted) {
      // Small delay to ensure navigation is complete
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          // Trigger coin purchase popup by setting the provider state directly
          _ref.read(coinPurchasePopupProvider.notifier).state = true;
        }
      });
    }
    
    if (mounted) {
      state = const CallConnectionState.idle();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Internals
  // ──────────────────────────────────────────────────────────────────────────

  /// Returns true if [status] indicates creator has accepted (we're connecting).
  bool _isCreatorAcceptedStatus(CallStatus status) {
    return status.runtimeType.toString().contains('Connecting') ||
        status.toString().contains('acceptedByCallee: true');
  }

  /// Listens for [CallStatusConnected] / [CallStatusDisconnected] via
  /// `call.partialState` — ignores participant/audio churn.
  void _listenForConnected(Call call) {
    _statusSubscription?.cancel();
    _statusSubscription =
        call.partialState((s) => s.status).listen((status) {
      debugPrint('📞 [CALL CTRL] status → $status');

      // Creator accepted — transition from ring phase to join phase.
      // Restart watchdog with longer timeout (30s) for WebRTC connection.
      if (state.isOutgoing && !_creatorAccepted && _isCreatorAcceptedStatus(status)) {
        _creatorAccepted = true;
        debugPrint('📞 [CALL CTRL] Creator accepted — restarting join-phase watchdog (30s)');
        _startJoinPhaseWatchdog();
      }

      if (status is CallStatusConnected) {
        CallRingtoneService.stop();
        _cancelWatchdog();
        if (state.phase == CallConnectionPhase.joining) {
          _wasConnected = true;
          state = CallConnectionState(
              phase: CallConnectionPhase.connected,
              call: call,
              isOutgoing: state.isOutgoing,
              remoteImageFallbackUrl: state.remoteImageFallbackUrl);

          // ── Start billing (both user-initiated and creator-initiated calls) ────────────
          _emitBillingStarted();

          // Already on /call screen (navigated during preparing phase)
          debugPrint(
              '✅ [CALL CTRL] phase → connected — call is live');
        }
      } else if (status is CallStatusDisconnected) {
        CallRingtoneService.stop();
        // Only handle unexpected disconnects (not our own endCall)
        if (state.phase != CallConnectionPhase.disconnecting &&
            state.phase != CallConnectionPhase.idle) {
          final reason = status.reason;
          debugPrint(
              '📞 [CALL CTRL] Unexpected disconnect: $reason');

          _cancelSubscriptions();

          // ── Stop billing on any unexpected disconnect ──────────
          final endedCallId = _activeCallId;
          final endedCreatorFirebaseUid = _activeCreatorFirebaseUid;
          final endedCreatorLookupId = _activeCreatorMongoId;
          final wasConnected = _wasConnected;
          if (_activeCallId != null) {
            debugPrint(
                '💰 [CALL CTRL] Emitting call:ended for $_activeCallId (unexpected disconnect)');
            final socketService = _ref.read(socketServiceProvider);
            socketService.emitCallEnded(callId: _activeCallId!);
          }
          _activeCallId = null;
          _activeCreatorFirebaseUid = null;
          _activeCreatorMongoId = null;
          _activeUserFirebaseUid = null;
          _wasConnected = false;

          // Map disconnect reason → failure or clean exit
          final isRejected = reason
              .toString()
              .toLowerCase()
              .contains('rejected');
          if (isRejected) {
            debugPrint('📞 [CALL CTRL] Call was rejected by remote party');
            if (mounted) {
              state = CallConnectionState(
                phase: CallConnectionPhase.failed,
                error: 'Call was declined',
                failureReason: CallFailureReason.rejected,
                isOutgoing: state.isOutgoing,
                remoteImageFallbackUrl: state.remoteImageFallbackUrl,
              );
            }
          } else {
            // Queue feedback prompt for the user who paid for the call
            // - User-initiated calls: isOutgoing = true, _activeUserFirebaseUid = null (user pays)
            // - Creator-initiated calls:
            //   * Creator's side: isOutgoing = true, _activeUserFirebaseUid is set (user pays, but creator shouldn't rate)
            //   * User's side: isOutgoing = false, _activeUserFirebaseUid = null (user pays, user should rate)
            // So we queue feedback if: wasConnected && we're NOT on creator's side of creator-initiated call
            // i.e., _activeUserFirebaseUid == null means we're the user who pays
            // Also ensure we're a regular user (not creator/admin) - only users should rate creators
            final authState = _ref.read(authProvider);
            final currentUser = authState.user;
            final isRegularUser = currentUser != null && currentUser.role == 'user';
            
            if (wasConnected &&
                _activeUserFirebaseUid == null &&
                isRegularUser &&
                endedCallId != null &&
                endedCallId.isNotEmpty) {
              _queuePostCallFeedbackPrompt(
                callId: endedCallId,
                creatorFirebaseUid: endedCreatorFirebaseUid,
                creatorLookupId: endedCreatorLookupId,
                call: call,
              );
            }

            // Normal disconnect (other party left, network, etc.)
            // Navigate both user and creator to home
            CallNavigationService.navigateToHome();
            
            // Show coin pack bottom sheet after call ends (only for regular users)
            if (wasConnected && isRegularUser && mounted) {
              // Small delay to ensure navigation is complete
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  // Trigger coin purchase popup by setting the provider state directly
                  _ref.read(coinPurchasePopupProvider.notifier).state = true;
                }
              });
            }
            
            if (mounted) {
              state = const CallConnectionState.idle();
            }
          }
        }
      }
    });
  }

  // ──── Billing emission with retry ────

  /// Emit `call:started` to the backend.
  ///
  /// 🔥 FIX: `emitCallStarted` now has a REST API fallback inside
  /// [SocketService], so even if the socket is not connected, billing
  /// will be triggered via HTTP.  The retry loop is kept as extra safety.
  void _emitBillingStarted() {
    if (_activeCallId == null ||
        _activeCreatorFirebaseUid == null ||
        _activeCreatorMongoId == null) {
      return; // No billing metadata — shouldn't happen
    }

    final socketService = _ref.read(socketServiceProvider);

    // Emit immediately — SocketService handles fallback to REST API
    // For creator-initiated calls, pass userFirebaseUid so the user (not creator) pays
    debugPrint('💰 [CALL CTRL] Emitting call:started');
    socketService.emitCallStarted(
      callId: _activeCallId!,
      creatorFirebaseUid: _activeCreatorFirebaseUid!,
      creatorMongoId: _activeCreatorMongoId!,
      userFirebaseUid: _activeUserFirebaseUid, // null for user-initiated, set for creator-initiated
    );
  }

  // ──── Two-phase watchdog ────
  //
  // Outgoing (user) calls:
  //   Phase 1 — Ring: 15s for creator to accept. If timeout → creatorNotPickedUp.
  //   Phase 2 — Join: 30s after creator accepts for WebRTC. If timeout → joinTimeout.
  //
  // Incoming (creator) calls:
  //   Single phase — 30s for WebRTC connection after accept.

  static const _ringTimeoutSeconds = 15;  // Creator must accept within 15s
  static const _joinTimeoutSeconds = 30;  // WebRTC connection after accept

  void _startWatchdog() {
    _cancelWatchdog();
    if (state.isOutgoing) {
      // Phase 1: Ring timeout — creator must accept within 15s
      _watchdog = Timer(const Duration(seconds: _ringTimeoutSeconds), () async {
        if (state.phase != CallConnectionPhase.joining) return;
        if (_creatorAccepted) return; // Already in join phase — shouldn't happen
        debugPrint('⏱️ [CALL CTRL] Ring timeout (15s) — creator did not pick up');
        await _cleanupCall();
        if (mounted) {
          // Navigate to home and show toast instead of full-page failed view
          _ref.read(creatorBusyToastProvider.notifier).state = 'Creator is busy';
          CallNavigationService.navigateToHome();
          state = const CallConnectionState.idle();
        }
      });
    } else {
      // Creator side: single 30s join timeout
      _watchdog = Timer(const Duration(seconds: _joinTimeoutSeconds), () async {
        if (state.phase == CallConnectionPhase.joining) {
          debugPrint('⏱️ [CALL CTRL] Join timeout (30s) — connection failed');
          await _cleanupCall();
          if (mounted) {
            state = const CallConnectionState(
              phase: CallConnectionPhase.failed,
              error: 'Connection timed out. Please try again.',
              failureReason: CallFailureReason.joinTimeout,
            );
          }
        }
      });
    }
  }

  /// Called when creator accepts — gives 30s for WebRTC to establish.
  void _startJoinPhaseWatchdog() {
    _cancelWatchdog();
    _watchdog = Timer(const Duration(seconds: _joinTimeoutSeconds), () async {
      if (state.phase == CallConnectionPhase.joining) {
        debugPrint('⏱️ [CALL CTRL] Join-phase timeout (30s) — connection failed');
        await _cleanupCall();
        if (mounted) {
          state = CallConnectionState(
            phase: CallConnectionPhase.failed,
            error: 'Connection timed out. Please try again.',
            failureReason: CallFailureReason.joinTimeout,
            isOutgoing: state.isOutgoing,
          );
        }
      }
    });
  }

  void _cancelWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  // ──── Cleanup helpers ────

  void _cancelSubscriptions() {
    _statusSubscription?.cancel();
    _statusSubscription = null;
    _cancelWatchdog();
  }

  /// Cancel subscriptions **and** try to leave the current call.
  Future<void> _cleanupCall() async {
    CallRingtoneService.stop();
    _cancelSubscriptions();
    try {
      await state.call?.leave();
    } catch (_) {}
  }

  void _queuePostCallFeedbackPrompt({
    required String callId,
    required String? creatorFirebaseUid,
    required String? creatorLookupId,
    required Call? call,
  }) {
    final creatorName = _extractRemoteCreatorName(call);
    _ref.read(callFeedbackPromptProvider.notifier).enqueue(
          CallFeedbackPrompt(
            callId: callId,
            creatorLookupId: creatorLookupId,
            creatorFirebaseUid: creatorFirebaseUid,
            creatorName: creatorName,
          ),
        );
  }

  String? _extractRemoteCreatorName(Call? call) {
    if (call == null) return null;
    final currentUserId = _ref.read(authProvider).firebaseUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) return null;

    try {
      final dynamic callState = (call as dynamic).state?.value;
      final dynamic members = callState?.members;
      if (members is Iterable) {
        for (final dynamic member in members) {
          final memberId = (member as dynamic).userId?.toString();
          if (memberId == null || memberId == currentUserId) continue;
          final dynamic user = (member as dynamic).user;
          final name = user?.name?.toString() ??
              user?.extraData?['username']?.toString() ??
              user?.id?.toString();
          if (name != null && name.trim().isNotEmpty) {
            return name.trim();
          }
        }
      }
    } catch (_) {
      // Best-effort only.
    }
    return null;
  }

  @override
  void dispose() {
    CallRingtoneService.stop();
    _cancelSubscriptions();
    super.dispose();
  }
}
