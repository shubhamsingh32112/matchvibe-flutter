import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import '../../auth/providers/auth_provider.dart';
import '../controllers/call_connection_controller.dart';
import '../providers/stream_video_provider.dart';
import '../services/call_ringtone_service.dart';
import '../utils/call_remote_image_resolver.dart';
import '../utils/remote_avatar_lookup.dart';
import '../../home/providers/home_provider.dart';
import '../../creator/providers/creator_availability_toggle_provider.dart';
import '../../creator/providers/creator_status_provider.dart';
import '../../../core/services/sentry_service.dart';
import 'incoming_call_widget.dart';

/// Widget that listens for incoming calls and shows UI when call arrives.
///
/// Should be placed high in the widget tree (e.g., in main app scaffold).
///
/// CRITICAL: Listens for CallRingingEvent to detect incoming calls.
/// Stream Video does NOT auto-show incoming calls — you must explicitly listen.
///
/// Overlay dismissal:
///   - Hidden when [CallConnectionController] is actively handling a call.
///   - Hidden when the caller cancels (SDK clears `state.incomingCall`).
///   - Hidden when the creator rejects the call.
///   - Calls that have been handled (accepted/rejected) are tracked by ID
///     and never re-shown — this prevents stale `valueOrNull` from
///     resurrecting the overlay after a call ends.
class IncomingCallListener extends ConsumerStatefulWidget {
  final Widget child;

  const IncomingCallListener({super.key, required this.child});

  @override
  ConsumerState<IncomingCallListener> createState() =>
      _IncomingCallListenerState();
}

class _IncomingCallListenerState extends ConsumerState<IncomingCallListener> {
  Call? _incomingCall;
  StreamSubscription? _ringingSubscription;
  StreamSubscription? _incomingCallSubscription;
  StreamSubscription<dynamic>? _incomingCallStateSubscription;
  ProviderSubscription<CallConnectionState>? _callStateSub;

  /// Ring timeout: if creator doesn't accept/reject within 15s, auto-dismiss.
  /// Matches user-side ring timeout — call ends for both parties.
  static const _ringTimeoutSeconds = 15;
  Timer? _ringTimeoutTimer;

  /// Call IDs that have already been handled (accepted, rejected, or ended).
  /// Prevents the overlay from re-appearing due to stale SDK state.
  final Set<String> _handledCallIds = {};
  final Map<String, String> _incomingFallbackImageByCallId = {};
  final Map<String, String> _incomingFallbackSourceByCallId = {};

  @override
  void initState() {
    super.initState();
    _callStateSub = ref.listenManual<CallConnectionState>(
      callConnectionControllerProvider,
      (prev, next) {
        if (next.phase != CallConnectionPhase.idle && _incomingCall != null) {
          _cancelRingTimeout();
          _handledCallIds.add(_incomingCall!.id);
          CallRingtoneService.stop();
          if (mounted) {
            setState(() {
              _incomingCall = null;
            });
          }
        }
      },
    );
    // Set up listener after first frame (when providers are ready)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupIncomingCallListener();
    });
  }

  void _setupIncomingCallListener() {
    final streamVideo = ref.read(streamVideoProvider);
    if (streamVideo == null) {
      debugPrint(
        '⏳ [INCOMING CALL] Stream Video not initialized yet, will retry on next build',
      );
      return;
    }

    // Cancel existing subscriptions if any
    _ringingSubscription?.cancel();
    _incomingCallSubscription?.cancel();

    if (kDebugMode) {
      debugPrint('📞 [INCOMING CALL] Setting up incoming call listener');
    }

    // Method 1: Listen for CoordinatorCallRingingEvent via events stream.
    _ringingSubscription = streamVideo.events.listen((event) {
      if (event is CoordinatorCallRingingEvent) {
        debugPrint('📞 [INCOMING CALL] CoordinatorCallRingingEvent received');
        debugPrint('   Call CID: ${event.callCid}');
        debugPrint(
          '   Call Type: ${event.callCid.type}, ID: ${event.callCid.id}',
        );
        debugPrint('   Video: ${event.video}');

        final callId = event.callCid.id;

        // Skip calls we've already handled
        if (_handledCallIds.contains(callId)) {
          debugPrint(
            '⏭️ [INCOMING CALL] Ignoring already-handled call: $callId',
          );
          return;
        }

        // Get the call object using makeCall (retrieves existing call).
        final call = streamVideo.makeCall(
          callType: StreamCallType.defaultType(),
          id: callId,
        );

        debugPrint('✅ [INCOMING CALL] Call object retrieved: ${call.id}');
        unawaited(() async {
          final suppressed = await _shouldSuppressIncoming(
            call,
            source: 'ring_event',
          );
          if (suppressed) return;
          _showIncomingCall(call);
        }());
      }
    });

    // Method 2: Also listen to state.incomingCall (recommended — simpler).
    _incomingCallSubscription = streamVideo.state.incomingCall.listen((call) {
      if (call != null) {
        // Skip calls we've already handled
        if (_handledCallIds.contains(call.id)) {
          debugPrint(
            '⏭️ [INCOMING CALL] Ignoring already-handled call via state: ${call.id}',
          );
          return;
        }
        debugPrint(
          '📞 [INCOMING CALL] Incoming call detected via state: ${call.id}',
        );
        unawaited(() async {
          final suppressed = await _shouldSuppressIncoming(
            call,
            source: 'state_incoming',
          );
          if (suppressed) return;
          _showIncomingCall(call);
        }());
      } else {
        debugPrint('📞 [INCOMING CALL] Incoming call cleared by SDK');
        _cancelRingTimeout();
        _incomingCallStateSubscription?.cancel();
        _incomingCallStateSubscription = null;
        CallRingtoneService.stop();
        final clearedCallId = _incomingCall?.id;
        if (mounted) {
          setState(() {
            _incomingCall = null;
            if (clearedCallId != null) {
              _incomingFallbackImageByCallId.remove(clearedCallId);
              _incomingFallbackSourceByCallId.remove(clearedCallId);
            }
          });
        }
      }
    });

    if (kDebugMode) {
      debugPrint('✅ [INCOMING CALL] Listener set up successfully');
    }
  }

  void _startRingTimeout(String callId) {
    _cancelRingTimeout();
    _ringTimeoutTimer = Timer(const Duration(seconds: _ringTimeoutSeconds), () {
      if (!mounted) return;
      if (_incomingCall?.id != callId) return;
      debugPrint(
        '⏱️ [INCOMING CALL] Ring timeout (${_ringTimeoutSeconds}s) — caller likely gave up',
      );
      _dismissIncomingCall(callId);
    });
  }

  void _cancelRingTimeout() {
    _ringTimeoutTimer?.cancel();
    _ringTimeoutTimer = null;
  }

  /// Explicitly dismiss the incoming call overlay and mark the call as handled.
  void _dismissIncomingCall(String callId) {
    _cancelRingTimeout();
    debugPrint('🚫 [INCOMING CALL] Dismissing call: $callId');
    _handledCallIds.add(callId);
    _incomingFallbackImageByCallId.remove(callId);
    _incomingFallbackSourceByCallId.remove(callId);
    _incomingCallStateSubscription?.cancel();
    _incomingCallStateSubscription = null;
    CallRingtoneService.stop();
    if (mounted) {
      setState(() {
        _incomingCall = null;
      });
    }
  }

  @override
  void didUpdateWidget(IncomingCallListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-setup listener if Stream Video becomes available
    final streamVideo = ref.read(streamVideoProvider);
    if (streamVideo != null && _ringingSubscription == null) {
      _setupIncomingCallListener();
    }
  }

  @override
  void dispose() {
    _cancelRingTimeout();
    CallRingtoneService.stop();
    _incomingFallbackImageByCallId.clear();
    _incomingFallbackSourceByCallId.clear();
    _callStateSub?.close();
    _incomingCallStateSubscription?.cancel();
    _ringingSubscription?.cancel();
    _incomingCallSubscription?.cancel();
    super.dispose();
  }

  void _showIncomingCall(Call call) {
    _primeIncomingCallState(call);
    _subscribeIncomingCallState(call);
    unawaited(_prefetchIncomingCallerAvatar(call));
    CallRingtoneService.startIncomingRingtone();
    _startRingTimeout(call.id);
    if (mounted) {
      setState(() {
        _incomingCall = call;
      });
    }
  }

  Future<bool> _shouldSuppressIncoming(
    Call call, {
    required String source,
  }) async {
    if (!_isCreatorAvailableForIncoming()) {
      return _rejectIncomingCall(
        call,
        source: source,
        reason: 'toggle_off',
        sentryMessage: 'incoming_auto_rejected_toggle_off',
      );
    }
    return _suppressIncomingIfBusy(call, source: source);
  }

  bool _isCreatorAvailableForIncoming() {
    final toggleOn = ref.read(creatorAvailabilityToggleProvider).toggleOn;
    if (!toggleOn) return false;
    final status = ref.read(creatorStatusProvider);
    return status == CreatorStatus.online;
  }

  Future<bool> _rejectIncomingCall(
    Call call, {
    required String source,
    required String reason,
    required String sentryMessage,
  }) async {
    debugPrint(
      '🛑 [INCOMING CALL] Auto-rejecting incoming ($reason) '
      '(incoming=${call.id}, source=$source)',
    );
    SentryService.addBreadcrumb(
      category: 'call',
      message: sentryMessage,
      data: {
        'reason': reason,
        'call_id': call.id,
        'source': source,
      },
    );

    _handledCallIds.add(call.id);
    _incomingFallbackImageByCallId.remove(call.id);
    _incomingFallbackSourceByCallId.remove(call.id);
    _cancelRingTimeout();
    CallRingtoneService.stop();
    if (_incomingCall?.id == call.id && mounted) {
      setState(() {
        _incomingCall = null;
      });
    }

    try {
      await call.reject();
    } catch (e) {
      debugPrint(
        '⚠️ [INCOMING CALL] Failed to auto-reject call ${call.id}: $e',
      );
    }
    return true;
  }

  Future<bool> _suppressIncomingIfBusy(
    Call call, {
    required String source,
  }) async {
    if (!_isLocalParticipantBusyForIncoming(call)) {
      return false;
    }

    final controller = ref.read(callConnectionControllerProvider);
    final activeSdkCallId = _resolveActiveSdkCallId();
    debugPrint(
      '🛑 [INCOMING CALL] Suppressing incoming while already in call '
      '(incoming=${call.id}, phase=${controller.phase.name}, source=$source, activeSdkCallId=$activeSdkCallId)',
    );
    SentryService.addBreadcrumb(
      category: 'call',
      message: 'incoming_suppressed_local_busy',
      data: {
        'reason': 'local_busy_in_active_call',
        'call_id': call.id,
        'phase': controller.phase.name,
        'source': source,
        if (activeSdkCallId != null) 'active_sdk_call_id': activeSdkCallId,
      },
    );
    return _rejectIncomingCall(
      call,
      source: source,
      reason: 'local_busy_in_active_call',
      sentryMessage: 'incoming_auto_rejected_local_busy',
    );
  }

  bool _isLocalParticipantBusyForIncoming(Call incomingCall) {
    if (_incomingCall != null && _incomingCall!.id != incomingCall.id) {
      return true;
    }

    final controller = ref.read(callConnectionControllerProvider);
    if (controller.isInActiveCallFlow) {
      return true;
    }

    final activeSdkCallId = _resolveActiveSdkCallId();
    if (activeSdkCallId != null && activeSdkCallId != incomingCall.id) {
      return true;
    }
    return false;
  }

  String? _resolveActiveSdkCallId() {
    final streamVideo = ref.read(streamVideoProvider);
    if (streamVideo == null) return null;
    try {
      final dynamic activeCallNotifier =
          (streamVideo as dynamic).state?.activeCall;
      final dynamic activeCall =
          activeCallNotifier?.valueOrNull ?? activeCallNotifier?.value;
      final activeCallId = activeCall?.id?.toString();
      if (activeCallId != null && activeCallId.isNotEmpty) {
        return activeCallId;
      }
    } catch (_) {
      // Best-effort active call check only.
    }
    return null;
  }

  void _subscribeIncomingCallState(Call call) {
    _incomingCallStateSubscription?.cancel();
    try {
      final dynamic stateStream = (call as dynamic).partialState(
        (dynamic state) => state,
      );
      _incomingCallStateSubscription = (stateStream as Stream<dynamic>).listen((
        _,
      ) {
        if (!mounted) return;
        if (_incomingCall?.id != call.id) return;
        if (_handledCallIds.contains(call.id)) return;
        unawaited(_prefetchIncomingCallerAvatar(call));
        setState(() {});
      });
    } catch (_) {
      // Best-effort hydration listener only.
    }
  }

  void _primeIncomingCallState(Call call) {
    unawaited(() async {
      try {
        await call.get().timeout(const Duration(seconds: 2));
      } catch (_) {
        // Ringing call may not always support immediate refresh; keep going.
      } finally {
        await _prefetchIncomingCallerAvatar(call);
      }
    }());
  }

  Future<void> _prefetchIncomingCallerAvatar(Call call) async {
    final currentUserId = ref.read(authProvider).firebaseUser?.uid;
    final fromCall = resolveRemoteImage(
      call: call,
      currentUserId: currentUserId,
      enableDebugLogs: true,
      debugSourceTag: 'incoming_prefetch',
    );
    if (fromCall != null) {
      if (mounted) {
        setState(() {
          _incomingFallbackImageByCallId[call.id] = fromCall.url;
          _incomingFallbackSourceByCallId[call.id] = fromCall.source;
        });
      }
      return;
    }

    // Fallback: lookup from user list first, then creators list
    try {
      final dynamic callState = (call as dynamic).state?.value;
      final createdBy = callState?.createdBy;
      final remoteFirebaseUid =
          createdBy?.id?.toString() ??
          createdBy?.userId?.toString() ??
          extractCallerFirebaseUidFromCallId(call.id);
      final remoteUsername =
          createdBy?.name?.toString() ??
          createdBy?.extraData?['username']?.toString();

      final calleeRole = ref.read(authProvider).user?.role;
      final cachedCreators = ref.read(creatorsProvider).valueOrNull;

      debugPrint(
        '🔍 [INCOMING CALL] Looking up avatar for: firebaseUid=$remoteFirebaseUid, username=$remoteUsername, calleeRole=$calleeRole',
      );

      final lookedUp = await lookupIncomingCallerAvatarResult(
        calleeRole: calleeRole,
        remoteFirebaseUid: remoteFirebaseUid,
        remoteUsername: remoteUsername,
        debugSourceTag: 'incoming_prefetch',
        cachedCreators: cachedCreators,
        incomingRing: true,
      );

      debugPrint(
        '🔍 [INCOMING CALL] Avatar lookup result: ${lookedUp?.url ?? "null"} (source: ${lookedUp?.source ?? "none"})',
      );

      if (lookedUp != null && lookedUp.url.isNotEmpty && mounted) {
        debugPrint(
          '✅ [INCOMING CALL] Setting fallback image for call ${call.id}: ${lookedUp.url}',
        );
        setState(() {
          _incomingFallbackImageByCallId[call.id] = lookedUp.url;
          _incomingFallbackSourceByCallId[call.id] = lookedUp.source;
        });
      } else {
        debugPrint('⚠️ [INCOMING CALL] No avatar found for call ${call.id}');
      }
    } catch (e) {
      debugPrint('❌ [INCOMING CALL] Avatar lookup error: $e');
      // Best-effort prefetch only.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch Stream Video provider — set up listener when it becomes available
    final streamVideo = ref.watch(streamVideoProvider);

    // Set up listener if Stream Video is available but listener isn't set up yet
    if (streamVideo != null && _ringingSubscription == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _setupIncomingCallListener();
        }
      });
    }

    // ── Controller-aware overlay dismissal ──────────────────────────────────
    final controllerActive = ref.watch(
      callConnectionControllerProvider.select((s) => s.isInActiveCallFlow),
    );

    // If controller is active, hide overlay immediately.
    if (controllerActive) {
      return widget.child;
    }

    // ── Determine whether an incoming call overlay should show ──────────────
    final incomingCall = _incomingCall;

    if (incomingCall != null && !_handledCallIds.contains(incomingCall.id)) {
      // Call is still ringing — show a centered modal dialog (dim background).
      return Stack(
        children: [
          widget.child,
          const ModalBarrier(
            dismissible: false,
            color: Color.fromRGBO(0, 0, 0, 0.45),
          ),
          IncomingCallWidget(
            incomingCall: incomingCall,
            fallbackImageUrl: _incomingFallbackImageByCallId[incomingCall.id],
            fallbackImageSource:
                _incomingFallbackSourceByCallId[incomingCall.id],
            onDismiss: () => _dismissIncomingCall(incomingCall.id),
          ),
        ],
      );
    }

    // No incoming call, show normal UI
    return widget.child;
  }
}
