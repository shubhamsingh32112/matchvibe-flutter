import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import '../controllers/call_connection_controller.dart';
import '../providers/stream_video_provider.dart';
import '../services/call_navigation_service.dart';
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
<<<<<<< HEAD

  /// Call IDs that have already been handled (accepted, rejected, or ended).
  /// Prevents the overlay from re-appearing due to stale SDK state.
  final Set<String> _handledCallIds = {};
=======
  StreamSubscription? _callStateSubscription;
  
  // 🔥 CRITICAL FIX: Hard boolean flag to kill incoming UI IMMEDIATELY
  // Once Accept is tapped, this becomes true and NEVER shows incoming UI again
  // This is INDEPENDENT of Stream state - we don't wait for Stream to update
  bool _hasAcceptedCall = false;
  String? _acceptedCallId; // Track which call was accepted
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed

  @override
  void initState() {
    super.initState();
    
    // 🔥 CRITICAL FIX: Register callback to IMMEDIATELY kill incoming UI
    // This is called the INSTANT Accept is tapped - before any async work
    CallNavigationService.setOnNavigatingToCall(() {
      if (mounted) {
        if (kDebugMode) {
          debugPrint('🔥 [INCOMING CALL] KILLING overlay IMMEDIATELY on navigation');
        }
        setState(() {
          _hasAcceptedCall = true;
          _acceptedCallId = _incomingCall?.id;
          _incomingCall = null;
        });
      }
    });
    
    // 🔧 POLISH: Register callback to reset state when call screen exits
    // This ensures clean state for the next incoming call
    CallNavigationService.setOnCallScreenExited(() {
      if (mounted) {
        if (kDebugMode) {
          debugPrint('🔧 [INCOMING CALL] Call screen exited - resetting accepted state');
        }
        setState(() {
          _hasAcceptedCall = false;
          _acceptedCallId = null;
        });
      }
    });
    
    // Set up listener after first frame (when providers are ready)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupIncomingCallListener();
    });
  }

  void _setupIncomingCallListener() {
    final streamVideo = ref.read(streamVideoProvider);
    if (streamVideo == null) {
<<<<<<< HEAD
      debugPrint(
          '⏳ [INCOMING CALL] Stream Video not initialized yet, will retry on next build');
=======
      if (kDebugMode) {
        debugPrint('⏳ [INCOMING CALL] Stream Video not initialized yet, will retry on next build');
      }
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
      return;
    }

    // Cancel existing subscriptions if any
    _ringingSubscription?.cancel();
    _incomingCallSubscription?.cancel();

    if (kDebugMode) {
      debugPrint('📞 [INCOMING CALL] Setting up incoming call listener');
    }

    // Method 1: Listen for CoordinatorCallRingingEvent via events stream.
    // This fires when a call starts ringing.
    // CRITICAL: Without this listener, incoming calls are received but never shown.
    _ringingSubscription = streamVideo.events.listen((event) {
      if (event is CoordinatorCallRingingEvent) {
<<<<<<< HEAD
        debugPrint('📞 [INCOMING CALL] CoordinatorCallRingingEvent received');
        debugPrint('   Call CID: ${event.callCid}');
        debugPrint(
            '   Call Type: ${event.callCid.type}, ID: ${event.callCid.id}');
        debugPrint('   Video: ${event.video}');

        // Skip calls we've already handled
        if (_handledCallIds.contains(event.callCid.id)) {
          debugPrint(
              '⏭️ [INCOMING CALL] Ignoring already-handled call: ${event.callCid.id}');
          return;
        }

        // Get the call object using makeCall (retrieves existing call).
=======
        if (kDebugMode) {
          debugPrint('📞 [INCOMING CALL] CoordinatorCallRingingEvent received');
          debugPrint('   Call CID: ${event.callCid}');
          debugPrint('   Video: ${event.video}');
        }
        
        final callId = event.callCid.id;
        
        // 🔥 CRITICAL: If this is a NEW call (different from accepted one), reset the flag
        if (_hasAcceptedCall && callId != _acceptedCallId) {
          if (kDebugMode) {
            debugPrint('📞 [INCOMING CALL] New call via event, resetting accepted flag');
          }
          _hasAcceptedCall = false;
          _acceptedCallId = null;
        }
        
        // 🔥 CRITICAL: If we already accepted THIS call, ignore the event
        if (_hasAcceptedCall && callId == _acceptedCallId) {
          if (kDebugMode) {
            debugPrint('⏭️ [INCOMING CALL] Ignoring event - already accepted this call');
          }
          return;
        }
        
        // Get the call object using makeCall (this retrieves existing call)
        // We use defaultType() since all our calls use 'default' type
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
        final call = streamVideo.makeCall(
          callType: StreamCallType.defaultType(),
          id: callId,
        );
<<<<<<< HEAD

        debugPrint('✅ [INCOMING CALL] Call object retrieved: ${call.id}');
=======
        
        if (kDebugMode) {
          debugPrint('✅ [INCOMING CALL] Call object retrieved: ${call.id}');
        }
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
        if (mounted) {
          setState(() {
            _incomingCall = call;
          });
        }
      }
    });

    // Method 2: Also listen to state.incomingCall (recommended — simpler).
    // Automatically provides the Call object when a call is ringing.
    // Also handles caller-cancellation: SDK emits null when caller hangs up.
    _incomingCallSubscription =
        streamVideo.state.incomingCall.listen((call) {
      if (call != null) {
<<<<<<< HEAD
        // Skip calls we've already handled
        if (_handledCallIds.contains(call.id)) {
          debugPrint(
              '⏭️ [INCOMING CALL] Ignoring already-handled call via state: ${call.id}');
          return;
        }
        debugPrint(
            '📞 [INCOMING CALL] Incoming call detected via state: ${call.id}');
=======
        if (kDebugMode) {
          debugPrint('📞 [INCOMING CALL] Incoming call detected via state: ${call.id}');
        }
        
        // 🔥 CRITICAL: If this is a NEW call (different from accepted one), reset the flag
        if (_hasAcceptedCall && call.id != _acceptedCallId) {
          if (kDebugMode) {
            debugPrint('📞 [INCOMING CALL] New call detected, resetting accepted flag');
          }
          _hasAcceptedCall = false;
          _acceptedCallId = null;
        }
        
        // 🔥 CRITICAL: If we already accepted THIS call, don't show UI again
        if (_hasAcceptedCall && call.id == _acceptedCallId) {
          if (kDebugMode) {
            debugPrint('⏭️ [INCOMING CALL] Ignoring - already accepted this call');
          }
          return;
        }
        
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
        if (mounted) {
          setState(() {
            _incomingCall = call;
          });
        }
<<<<<<< HEAD
      } else {
        debugPrint('📞 [INCOMING CALL] Incoming call cleared by SDK');
=======
        
        // Listen to call state changes to clear incoming call overlay
        // Clear overlay on ANY of: accepted, joined, connecting, connected
        _callStateSubscription = call.state.listen((callState) {
          final status = callState.status;
          // Clear overlay if call is joining, joined, or connected
          if (status is CallStatusJoining || 
              status is CallStatusJoined || 
              status is CallStatusConnected) {
            if (kDebugMode) {
              debugPrint('✅ [INCOMING CALL] Call state changed to ${status.runtimeType} - clearing overlay');
            }
            if (mounted) {
              setState(() {
                _hasAcceptedCall = true;
                _acceptedCallId = call.id;
                _incomingCall = null;
              });
            }
            // Cancel subscription once call is no longer incoming
            _callStateSubscription?.cancel();
            _callStateSubscription = null;
          }
        });
      } else {
        if (kDebugMode) {
          debugPrint('📞 [INCOMING CALL] Incoming call cleared by Stream');
        }
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
        if (mounted) {
          setState(() {
            _incomingCall = null;
            // Don't reset _hasAcceptedCall here - Stream clearing doesn't mean we should show UI again
          });
        }
      }
    });

    if (kDebugMode) {
      debugPrint('✅ [INCOMING CALL] Listener set up successfully');
    }
  }

  /// Explicitly dismiss the incoming call overlay and mark the call as handled.
  ///
  /// Called when the creator rejects the call or when the caller cancels.
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
    // Clear all callbacks on dispose
    CallNavigationService.setOnNavigatingToCall(null);
    CallNavigationService.setOnCallScreenExited(null);
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
<<<<<<< HEAD

    // ── Controller-aware overlay dismissal ──────────────────────────────────
    //
    // When the controller is actively handling a call (preparing / joining /
    // connected / disconnecting), the incoming-call overlay must NOT show.
    final controllerPhase =
        ref.watch(callConnectionControllerProvider).phase;
    final controllerActive =
        controllerPhase != CallConnectionPhase.idle &&
            controllerPhase != CallConnectionPhase.failed;

    // When the controller starts working on a call, mark it as handled
    // so the overlay never re-appears for this call ID.
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

    // Only use _incomingCall (set by event/state subscriptions).
    // Do NOT fall back to valueOrNull — it can return stale call objects
    // after a call has ended, causing the overlay to re-appear.
    final incomingCall = _incomingCall;

    if (incomingCall != null && !_handledCallIds.contains(incomingCall.id)) {
      // Call is still ringing — show overlay
=======
    
    // 🔥 CRITICAL FIX #1: If we already accepted a call, NEVER show incoming UI
    // This is the PRIMARY guard - completely independent of Stream state
    // Prevents the "stuck on incoming screen" bug
    if (_hasAcceptedCall) {
      return widget.child;
    }
    
    // Also check state.incomingCall as fallback (in case event listener missed it)
    // CRITICAL: Use valueOrNull instead of .value - ValueStream doesn't always have a value
    final stateIncomingCall = streamVideo?.state.incomingCall.valueOrNull;
    
    // 🔥 CRITICAL FIX #2: If stateIncomingCall is for a call we already accepted, ignore it
    if (stateIncomingCall != null && stateIncomingCall.id == _acceptedCallId) {
      return widget.child;
    }
    
    // Use either the event-based call or the state-based call
    final incomingCall = _incomingCall ?? stateIncomingCall;

    // Only show overlay if there's an incoming call
    if (incomingCall != null) {
      // 🔥 CRITICAL FIX #3: Only show if call status is ACTUALLY incoming/ringing
      // Stream docs: "Incoming call UI is only valid when CallStatusIncoming"
      final callState = incomingCall.state.valueOrNull;
      final status = callState?.status;
      
      // If status is null, the call just arrived - show UI
      // If status is "incoming" or similar ringing state, show UI
      // If status is joining/joined/connected, DON'T show UI
      if (status != null && 
          (status is CallStatusJoining || 
           status is CallStatusJoined || 
           status is CallStatusConnected ||
           status is CallStatusReconnecting)) {
        // Call is already past ringing - don't show overlay
        if (_incomingCall != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _hasAcceptedCall = true;
                _acceptedCallId = incomingCall.id;
                _incomingCall = null;
              });
            }
          });
        }
        return widget.child;
      }
      
      // 🔥 CRITICAL FIX #4: Check if we're already on call screen
      if (CallNavigationService.isOnCallScreen) {
        return widget.child;
      }
      
      // Call is still ringing - show overlay
      if (kDebugMode) {
        debugPrint('📞 [INCOMING CALL] Showing overlay for ${incomingCall.id}');
      }
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
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
