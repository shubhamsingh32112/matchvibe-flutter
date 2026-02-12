import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import '../controllers/call_connection_controller.dart';
import '../providers/stream_video_provider.dart';
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

  const IncomingCallListener({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<IncomingCallListener> createState() =>
      _IncomingCallListenerState();
}

class _IncomingCallListenerState extends ConsumerState<IncomingCallListener> {
  Call? _incomingCall;
  StreamSubscription? _ringingSubscription;
  StreamSubscription? _incomingCallSubscription;

  /// Call IDs that have already been handled (accepted, rejected, or ended).
  /// Prevents the overlay from re-appearing due to stale SDK state.
  final Set<String> _handledCallIds = {};

  @override
  void initState() {
    super.initState();
    // Set up listener after first frame (when providers are ready)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupIncomingCallListener();
    });
  }

  void _setupIncomingCallListener() {
    final streamVideo = ref.read(streamVideoProvider);
    if (streamVideo == null) {
      debugPrint(
          '⏳ [INCOMING CALL] Stream Video not initialized yet, will retry on next build');
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
            '   Call Type: ${event.callCid.type}, ID: ${event.callCid.id}');
        debugPrint('   Video: ${event.video}');

        final callId = event.callCid.id;

        // Skip calls we've already handled
        if (_handledCallIds.contains(callId)) {
          debugPrint(
              '⏭️ [INCOMING CALL] Ignoring already-handled call: $callId');
          return;
        }

        // Get the call object using makeCall (retrieves existing call).
        final call = streamVideo.makeCall(
          callType: StreamCallType.defaultType(),
          id: callId,
        );

        debugPrint('✅ [INCOMING CALL] Call object retrieved: ${call.id}');
        if (mounted) {
          setState(() {
            _incomingCall = call;
          });
        }
      }
    });

    // Method 2: Also listen to state.incomingCall (recommended — simpler).
    _incomingCallSubscription =
        streamVideo.state.incomingCall.listen((call) {
      if (call != null) {
        // Skip calls we've already handled
        if (_handledCallIds.contains(call.id)) {
          debugPrint(
              '⏭️ [INCOMING CALL] Ignoring already-handled call via state: ${call.id}');
          return;
        }
        debugPrint(
            '📞 [INCOMING CALL] Incoming call detected via state: ${call.id}');
        if (mounted) {
          setState(() {
            _incomingCall = call;
          });
        }
      } else {
        debugPrint('📞 [INCOMING CALL] Incoming call cleared by SDK');
        if (mounted) {
          setState(() {
            _incomingCall = null;
          });
        }
      }
    });

    if (kDebugMode) {
      debugPrint('✅ [INCOMING CALL] Listener set up successfully');
    }
  }

  /// Explicitly dismiss the incoming call overlay and mark the call as handled.
  void _dismissIncomingCall(String callId) {
    debugPrint('🚫 [INCOMING CALL] Dismissing call: $callId');
    _handledCallIds.add(callId);
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
    _ringingSubscription?.cancel();
    _incomingCallSubscription?.cancel();
    super.dispose();
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
    final controllerPhase =
        ref.watch(callConnectionControllerProvider).phase;
    final controllerActive =
        controllerPhase != CallConnectionPhase.idle &&
            controllerPhase != CallConnectionPhase.failed;

    // When the controller starts working on a call, mark it as handled
    ref.listen<CallConnectionState>(callConnectionControllerProvider,
        (prev, next) {
      if (next.phase != CallConnectionPhase.idle &&
          next.phase != CallConnectionPhase.failed &&
          _incomingCall != null) {
        _handledCallIds.add(_incomingCall!.id);
        setState(() {
          _incomingCall = null;
        });
      }
    });

    // If controller is active, hide overlay immediately.
    if (controllerActive) {
      return widget.child;
    }

    // ── Determine whether an incoming call overlay should show ──────────────
    final incomingCall = _incomingCall;

    if (incomingCall != null && !_handledCallIds.contains(incomingCall.id)) {
      // Call is still ringing — show overlay
      return Stack(
        children: [
          widget.child,
          // Full-screen overlay for incoming call
          Material(
            color: Colors.black54,
            child: IncomingCallWidget(
              incomingCall: incomingCall,
              onDismiss: () => _dismissIncomingCall(incomingCall.id),
            ),
          ),
        ],
      );
    }

    // No incoming call, show normal UI
    return widget.child;
  }
}
