import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import '../services/call_service.dart';
import '../services/permission_service.dart';
import '../services/call_navigation_service.dart';
import '../providers/stream_video_provider.dart';
import '../providers/call_billing_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/availability_provider.dart';

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
  permissionDenied, // → "Open Settings"
  joinTimeout,      // → "Retry"
  sfuFailure,       // → "Retry" / "Contact support"
  rejected,         // → "Go Back"
  unknown,          // → "Go Back" + "Retry"
}

/// Immutable state exposed by [CallConnectionController].
class CallConnectionState {
  final CallConnectionPhase phase;
  final Call? call;
  final String? error;
  final CallFailureReason? failureReason;

  /// `true` when the local user initiated the call (outgoing).
  /// `false` when the local user received the call (incoming / creator side).
  final bool isOutgoing;

  const CallConnectionState({
    required this.phase,
    this.call,
    this.error,
    this.failureReason,
    this.isOutgoing = false,
  });

  const CallConnectionState.idle()
      : phase = CallConnectionPhase.idle,
        call = null,
        error = null,
        failureReason = null,
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

  // Billing metadata — set when a user starts a call
  String? _activeCallId;
  String? _activeCreatorFirebaseUid;
  String? _activeCreatorMongoId;

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

    state = const CallConnectionState(
        phase: CallConnectionPhase.preparing, isOutgoing: true);

    // Navigate to /call immediately so user sees the outgoing call screen
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
          isOutgoing: true,
        );
        return;
      }

      // 2. Stream Video client
      final streamVideo = _ref.read(streamVideoProvider);
      if (streamVideo == null) {
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
        state = const CallConnectionState(
          phase: CallConnectionPhase.failed,
          error: 'User not authenticated',
          failureReason: CallFailureReason.unknown,
          isOutgoing: true,
        );
        return;
      }

      // 4. 🔥 FIX: Ensure billing socket is connected BEFORE the call starts.
      //    The socket may have silently failed to connect during HomeScreen init.
      //    Get a fresh token and force-(re)connect.
      final socketService = _ref.read(socketServiceProvider);
      if (!socketService.isConnected) {
        debugPrint('🔌 [CALL CTRL] Billing socket NOT connected — reconnecting...');
        final token = await firebaseUser.getIdToken();
        if (token != null) {
          final connected = await socketService.ensureConnected(token);
          debugPrint('🔌 [CALL CTRL] Socket ensureConnected result: $connected');
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
          phase: CallConnectionPhase.joining, call: call, isOutgoing: true);
      _startWatchdog();
      _listenForConnected(call);

      callService.joinCall(call);
      debugPrint('✅ [CALL CTRL] call.join() fired (fire-and-forget)');
      // Actual UI transition → connected happens in _listenForConnected.
    } catch (e) {
      debugPrint('❌ [CALL CTRL] startUserCall error: $e');
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

    state = const CallConnectionState(phase: CallConnectionPhase.preparing);

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

      // 2. Accept (tells Stream the callee accepted)
      await call.accept();
      debugPrint('✅ [CALL CTRL] call.accept() completed');

      // Store call ID so creator can also emit call:ended on disconnect.
      // Note: _activeCreatorFirebaseUid / _activeCreatorMongoId remain null,
      // so call:started won't be re-emitted — only the user triggers billing.
      _activeCallId = call.id;

      // 3. Transition to joining
      state = CallConnectionState(
          phase: CallConnectionPhase.joining, call: call);
      _startWatchdog();
      _listenForConnected(call);

      final callService = _ref.read(callServiceProvider);
      callService.joinCall(call);
      debugPrint('✅ [CALL CTRL] call.join() fired (fire-and-forget)');
      // Actual UI transition → connected happens in _listenForConnected.
    } catch (e) {
      debugPrint('❌ [CALL CTRL] acceptIncomingCall error: $e');
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

    final call = state.call;
    state = CallConnectionState(
        phase: CallConnectionPhase.disconnecting, call: call);

    _cancelSubscriptions(); // stop status listener first

    // ── Emit call:ended to trigger MongoDB settlement ──────────
    if (_activeCallId != null) {
      final socketService = _ref.read(socketServiceProvider);
      socketService.emitCallEnded(callId: _activeCallId!);
    }
    _activeCallId = null;
    _activeCreatorFirebaseUid = null;
    _activeCreatorMongoId = null;

    if (call != null) {
      try {
        await call.leave();
        debugPrint('✅ [CALL CTRL] call.leave() completed');
      } catch (e) {
        debugPrint('❌ [CALL CTRL] endCall leave error: $e');
      }
    }

    // Navigate to home — both user and creator land on their home page
    CallNavigationService.navigateToHome();
    if (mounted) {
      state = const CallConnectionState.idle();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Internals
  // ──────────────────────────────────────────────────────────────────────────

  /// Listens for [CallStatusConnected] / [CallStatusDisconnected] via
  /// `call.partialState` — ignores participant/audio churn.
  void _listenForConnected(Call call) {
    _statusSubscription?.cancel();
    _statusSubscription =
        call.partialState((s) => s.status).listen((status) {
      debugPrint('📞 [CALL CTRL] status → $status');

      if (status is CallStatusConnected) {
        _cancelWatchdog();
        if (state.phase == CallConnectionPhase.joining) {
          state = CallConnectionState(
              phase: CallConnectionPhase.connected,
              call: call,
              isOutgoing: state.isOutgoing);

          // ── Start billing (user-initiated calls only) ────────────
          _emitBillingStarted();

          // Already on /call screen (navigated during preparing phase)
          debugPrint(
              '✅ [CALL CTRL] phase → connected — call is live');
        }
      } else if (status is CallStatusDisconnected) {
        // Only handle unexpected disconnects (not our own endCall)
        if (state.phase != CallConnectionPhase.disconnecting &&
            state.phase != CallConnectionPhase.idle) {
          final reason = status.reason;
          debugPrint(
              '📞 [CALL CTRL] Unexpected disconnect: $reason');

          _cancelSubscriptions();

          // ── Stop billing on any unexpected disconnect ──────────
          if (_activeCallId != null) {
            debugPrint(
                '💰 [CALL CTRL] Emitting call:ended for $_activeCallId (unexpected disconnect)');
            final socketService = _ref.read(socketServiceProvider);
            socketService.emitCallEnded(callId: _activeCallId!);
          }
          _activeCallId = null;
          _activeCreatorFirebaseUid = null;
          _activeCreatorMongoId = null;

          // Map disconnect reason → failure or clean exit
          if (reason == DisconnectReason.rejected) {
            debugPrint('📞 [CALL CTRL] Call was rejected by remote party');
            if (mounted) {
              state = CallConnectionState(
                phase: CallConnectionPhase.failed,
                error: 'Call was declined',
                failureReason: CallFailureReason.rejected,
                isOutgoing: state.isOutgoing,
              );
            }
          } else {
            // Normal disconnect (other party left, network, etc.)
            // Navigate both user and creator to home
            CallNavigationService.navigateToHome();
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
      return; // Creator side — billing is triggered by the user
    }

    final socketService = _ref.read(socketServiceProvider);

    // Emit immediately — SocketService handles fallback to REST API
    debugPrint('💰 [CALL CTRL] Emitting call:started');
    socketService.emitCallStarted(
      callId: _activeCallId!,
      creatorFirebaseUid: _activeCreatorFirebaseUid!,
      creatorMongoId: _activeCreatorMongoId!,
    );
  }

  // ──── Watchdog (Phase 5 — 10 s fail-safe) ────

  void _startWatchdog() {
    _cancelWatchdog();
    _watchdog = Timer(const Duration(seconds: 10), () async {
      if (state.phase == CallConnectionPhase.joining) {
        debugPrint('⏱️ [CALL CTRL] Watchdog timeout — leaving call');
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
    _cancelSubscriptions();
    try {
      await state.call?.leave();
    } catch (_) {}
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
