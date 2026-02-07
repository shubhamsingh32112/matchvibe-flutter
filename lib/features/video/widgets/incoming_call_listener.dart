import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import '../providers/stream_video_provider.dart';
import '../services/call_navigation_service.dart';
import 'incoming_call_widget.dart';

/// Widget that listens for incoming calls and shows UI when call arrives
/// 
/// Should be placed high in the widget tree (e.g., in main app scaffold)
/// 
/// CRITICAL: Listens for CallRingingEvent to detect incoming calls
/// Stream Video does NOT auto-show incoming calls - you must explicitly listen
class IncomingCallListener extends ConsumerStatefulWidget {
  final Widget child;

  const IncomingCallListener({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends ConsumerState<IncomingCallListener> {
  Call? _incomingCall;
  StreamSubscription? _ringingSubscription;
  StreamSubscription? _incomingCallSubscription;
  StreamSubscription? _callStateSubscription;
  
  // 🔥 CRITICAL FIX: Hard boolean flag to kill incoming UI IMMEDIATELY
  // Once Accept is tapped, this becomes true and NEVER shows incoming UI again
  // This is INDEPENDENT of Stream state - we don't wait for Stream to update
  bool _hasAcceptedCall = false;
  String? _acceptedCallId; // Track which call was accepted

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
      if (kDebugMode) {
        debugPrint('⏳ [INCOMING CALL] Stream Video not initialized yet, will retry on next build');
      }
      return;
    }

    // Cancel existing subscriptions if any
    _ringingSubscription?.cancel();
    _incomingCallSubscription?.cancel();

    if (kDebugMode) {
      debugPrint('📞 [INCOMING CALL] Setting up incoming call listener');
    }

    // Method 1: Listen for CoordinatorCallRingingEvent via events stream
    // This fires when a call starts ringing
    // CRITICAL: Without this listener, incoming calls are received but never shown
    _ringingSubscription = streamVideo.events.listen((event) {
      if (event is CoordinatorCallRingingEvent) {
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
        final call = streamVideo.makeCall(
          callType: StreamCallType.defaultType(),
          id: callId,
        );
        
        if (kDebugMode) {
          debugPrint('✅ [INCOMING CALL] Call object retrieved: ${call.id}');
        }
        if (mounted) {
          setState(() {
            _incomingCall = call;
          });
        }
      }
    });

    // Method 2: Also listen to state.incomingCall (recommended - simpler approach)
    // This is a StateEmitter that updates when incoming call changes
    // This automatically provides the Call object when a call is ringing
    _incomingCallSubscription = streamVideo.state.incomingCall.listen((call) {
      // Cancel previous call state subscription if any
      _callStateSubscription?.cancel();
      
      if (call != null) {
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
        
        if (mounted) {
          setState(() {
            _incomingCall = call;
          });
        }
        
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
    _callStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch Stream Video provider - set up listener when it becomes available
    final streamVideo = ref.watch(streamVideoProvider);
    
    // Set up listener if Stream Video is available but listener isn't set up yet
    if (streamVideo != null && _ringingSubscription == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _setupIncomingCallListener();
        }
      });
    }
    
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
      return Stack(
        children: [
          widget.child,
          // Full-screen overlay for incoming call
          Material(
            color: Colors.black54,
            child: IncomingCallWidget(incomingCall: incomingCall),
          ),
        ],
      );
    }

    // No incoming call, show normal UI
    return widget.child;
  }
}
