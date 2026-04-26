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
import '../../../core/api/api_client.dart' as api;
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
  ProviderSubscription<CallConnectionState>? _callStateSub;

  /// Ring timeout: if creator doesn't accept/reject within 15s, auto-dismiss.
  /// Matches user-side ring timeout — call ends for both parties.
  static const _ringTimeoutSeconds = 15;
  Timer? _ringTimeoutTimer;

  /// Call IDs that have already been handled (accepted, rejected, or ended).
  /// Prevents the overlay from re-appearing due to stale SDK state.
  final Set<String> _handledCallIds = {};
  final Map<String, String> _incomingFallbackImageByCallId = {};

  @override
  void initState() {
    super.initState();
    _callStateSub = ref.listenManual<CallConnectionState>(
      callConnectionControllerProvider,
      (prev, next) {
        if (next.phase != CallConnectionPhase.idle &&
            next.phase != CallConnectionPhase.failed &&
            _incomingCall != null) {
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
        unawaited(_prefetchIncomingCallerAvatar(call));
        CallRingtoneService.startIncomingRingtone();
        _startRingTimeout(callId);
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
        unawaited(_prefetchIncomingCallerAvatar(call));
        CallRingtoneService.startIncomingRingtone();
        _startRingTimeout(call.id);
        if (mounted) {
          setState(() {
            _incomingCall = call;
          });
        }
      } else {
        debugPrint('📞 [INCOMING CALL] Incoming call cleared by SDK');
        _cancelRingTimeout();
        CallRingtoneService.stop();
        if (mounted) {
          setState(() {
            _incomingCall = null;
            if (call != null) {
              _incomingFallbackImageByCallId.remove(call.id);
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
    _ringTimeoutTimer = Timer(
      const Duration(seconds: _ringTimeoutSeconds),
      () {
        if (!mounted) return;
        if (_incomingCall?.id != callId) return;
        debugPrint(
            '⏱️ [INCOMING CALL] Ring timeout (${_ringTimeoutSeconds}s) — caller likely gave up');
        _dismissIncomingCall(callId);
      },
    );
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
    _callStateSub?.close();
    _ringingSubscription?.cancel();
    _incomingCallSubscription?.cancel();
    super.dispose();
  }

  Future<void> _prefetchIncomingCallerAvatar(Call call) async {
    final currentUserId = ref.read(authProvider).firebaseUser?.uid;
    
    // First, try to resolve from call metadata
    final fromCall = resolveRemoteImageUrl(
      call: call,
      currentUserId: currentUserId,
      enableDebugLogs: true,
      debugSourceTag: 'incoming_prefetch',
    );
    if (fromCall != null) {
      if (mounted) {
        setState(() {
          _incomingFallbackImageByCallId[call.id] = fromCall;
        });
      }
      return;
    }

    // If not found in call metadata, try to extract from call members
    try {
      final dynamic callState = (call as dynamic).state?.value;
      final members = callState?.members;
      if (members is Iterable) {
        for (final dynamic member in members) {
          final memberId = (member as dynamic).userId?.toString() ??
              (member as dynamic).user?.id?.toString() ??
              (member as dynamic).user?.userId?.toString();
          
          if (memberId == null || 
              (currentUserId != null && memberId == currentUserId)) {
            continue; // Skip current user
          }

          // Try to get image from member
          final memberImage = (member as dynamic).user?.image?.toString() ??
              (member as dynamic).user?.imageUrl?.toString() ??
              (member as dynamic).image?.toString();
          
          if (memberImage != null && memberImage.trim().isNotEmpty) {
            if (mounted) {
              setState(() {
                _incomingFallbackImageByCallId[call.id] = memberImage.trim();
              });
            }
            return;
          }
        }
      }
    } catch (_) {
      // Continue to fallback lookup
    }

    // Fallback: lookup from user list first, then creators list
    try {
      final dynamic callState = (call as dynamic).state?.value;
      final createdBy = callState?.createdBy;
      final remoteFirebaseUid = createdBy?.id?.toString() ??
          createdBy?.userId?.toString() ??
          extractCallerFirebaseUidFromCallId(call.id);
      final remoteUsername = createdBy?.name?.toString() ??
          createdBy?.extraData?['username']?.toString();

      debugPrint('🔍 [INCOMING CALL] Looking up avatar for: firebaseUid=$remoteFirebaseUid, username=$remoteUsername');

      // First try user list
      var lookedUp = await lookupAvatarFromUserList(
        remoteFirebaseUid: remoteFirebaseUid,
        remoteUsername: remoteUsername,
        debugSourceTag: 'incoming_prefetch',
      );
      
      debugPrint('🔍 [INCOMING CALL] User list lookup result: ${lookedUp ?? "null"}');
      
      // If not found in user list, try creators list (for creator-initiated calls)
      if (lookedUp == null && remoteFirebaseUid != null && remoteFirebaseUid.isNotEmpty) {
        debugPrint('🔍 [INCOMING CALL] Trying creators list lookup...');
        lookedUp = await _lookupAvatarFromCreatorsList(
          remoteFirebaseUid: remoteFirebaseUid,
          remoteUsername: remoteUsername,
        );
        debugPrint('🔍 [INCOMING CALL] Creators list lookup result: ${lookedUp ?? "null"}');
      }
      
      if (lookedUp != null && lookedUp.isNotEmpty && mounted) {
        debugPrint('✅ [INCOMING CALL] Setting fallback image for call ${call.id}: $lookedUp');
        setState(() {
          _incomingFallbackImageByCallId[call.id] = lookedUp!;
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
    final controllerPhase =
        ref.watch(callConnectionControllerProvider).phase;
    final controllerActive =
        controllerPhase != CallConnectionPhase.idle &&
            controllerPhase != CallConnectionPhase.failed;

    // If controller is active, hide overlay immediately.
    if (controllerActive) {
      return widget.child;
    }

    // ── Determine whether an incoming call overlay should show ──────────────
    final incomingCall = _incomingCall;

    if (incomingCall != null && !_handledCallIds.contains(incomingCall.id)) {
      // Call is still ringing — show top-sheet style UI that keeps app header visible.
      return Stack(
        children: [
          widget.child,
          IncomingCallWidget(
            incomingCall: incomingCall,
            fallbackImageUrl: _incomingFallbackImageByCallId[incomingCall.id],
            onDismiss: () => _dismissIncomingCall(incomingCall.id),
          ),
        ],
      );
    }

    // No incoming call, show normal UI
    return widget.child;
  }

  /// Lookup avatar from creators list (for creator-initiated calls)
  Future<String?> _lookupAvatarFromCreatorsList({
    String? remoteFirebaseUid,
    String? remoteUsername,
  }) async {
    if (remoteFirebaseUid == null || remoteFirebaseUid.isEmpty) {
      return null;
    }

    try {
      final response = await api.ApiClient().get('/creator');
      final creatorsData = response.data?['data']?['creators'];
      if (creatorsData is! List) {
        return null;
      }

      for (final item in creatorsData) {
        if (item is! Map) continue;
        final creator = Map<String, dynamic>.from(item);

        final creatorFirebaseUidRaw = creator['firebaseUid'];
        final creatorNameRaw = creator['name'];
        final creatorFirebaseUid = creatorFirebaseUidRaw != null
            ? creatorFirebaseUidRaw.toString().trim()
            : null;
        final creatorName = creatorNameRaw != null
            ? creatorNameRaw.toString().trim()
            : null;

        // Match by Firebase UID (preferred) or name
        final idMatched = creatorFirebaseUid != null &&
            creatorFirebaseUid.isNotEmpty &&
            creatorFirebaseUid.toLowerCase() == remoteFirebaseUid.toLowerCase();
        final nameMatched = remoteUsername != null &&
            remoteUsername.isNotEmpty &&
            creatorName != null &&
            creatorName.isNotEmpty &&
            creatorName.toLowerCase() == remoteUsername.toLowerCase();

        if (!idMatched && !nameMatched) continue;

        // Get creator photo
        final photoRaw = creator['photo'];
        final photo = photoRaw != null ? photoRaw.toString().trim() : null;
        if (photo != null && photo.isNotEmpty) {
          debugPrint(
            '✅ [INCOMING CALL] Creator avatar found from /creator list: $photo',
          );
          return photo;
        }
      }
    } catch (e) {
      debugPrint(
        '❌ [INCOMING CALL] /creator lookup failed: $e',
      );
    }

    return null;
  }
}
