import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import '../services/security_service.dart';
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

    return _VideoCallScreenContent(call: call);
  }
}

/// Internal stateful widget for call screen content
class _VideoCallScreenContent extends ConsumerStatefulWidget {
  final Call call;

  const _VideoCallScreenContent({required this.call});

  @override
  ConsumerState<_VideoCallScreenContent> createState() => _VideoCallScreenContentState();
}

class _VideoCallScreenContentState extends ConsumerState<_VideoCallScreenContent> {
  bool _isScreenCaptured = false;
  
  // PHASE 5: Visual timer state
  int _remainingCoins = 0;
  Timer? _coinTimer;
  bool _coinsExhausted = false;
  bool _timerStarted = false; // 🔥 FIX 3: Track if timer has started

  StreamSubscription? _callStateSubscription;

  @override
  void initState() {
    super.initState();
    _setupSecurity();
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
  }

  @override
  void dispose() {
    // PHASE 5: Clean up timer
    _coinTimer?.cancel();
    // Clean up call state subscription
    _callStateSubscription?.cancel();
    // Disable security when leaving call screen
    SecurityService.disableCallSecurity();
    super.dispose();
  }

  /// Phase 4: Max participants enforcement (double lock)
  /// 
  /// Defense in depth: Check participant count client-side
  /// Protects against:
  /// - Misconfigured dashboard permissions
  /// - Accidental future feature creep
  /// 
  /// If participantCount > 2, immediately leave call
  void _checkMaxParticipants() {
    final callStateEmitter = widget.call.state;
    if (!callStateEmitter.hasValue) return;
    
    final callState = callStateEmitter.value;
    final participants = callState.callParticipants;
    final participantCount = participants.length;

    if (participantCount > 2) {
      debugPrint('🚨 [CALL] Max participants exceeded: $participantCount (max: 2)');
      debugPrint('   Leaving call immediately for security');
      
      // Log error for monitoring
      debugPrint('❌ [CALL] SECURITY VIOLATION: More than 2 participants detected');
      
      // Leave call immediately
      _handleMaxParticipantsExceeded();
    }
  }

  /// Handle max participants exceeded
  Future<void> _handleMaxParticipantsExceeded() async {
    try {
      final callService = ref.read(callServiceProvider);
      await callService.leaveCall(widget.call);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call ended: Maximum participants exceeded'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        
        // Navigate back
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('❌ [CALL] Error handling max participants: $e');
    }
  }

  /// Setup platform-level security (Phase 6)
  Future<void> _setupSecurity() async {
    // Enable security (Android: FLAG_SECURE, iOS: screen capture detection)
    await SecurityService.enableCallSecurity();

    // Listen for screen capture changes (iOS)
    SecurityService.setOnScreenCaptureChanged((isCaptured) {
      if (mounted) {
        setState(() {
          _isScreenCaptured = isCaptured;
        });

        if (isCaptured) {
          // Screen recording detected - disconnect call
          debugPrint('🚫 [SECURITY] Screen recording detected - disconnecting call');
          _handleScreenCaptureDetected();
        }
      }
    });
  }

  /// Handle screen capture detection (iOS)
  /// 
  /// Disconnects call when screen recording starts
  Future<void> _handleScreenCaptureDetected() async {
    try {
      final callService = ref.read(callServiceProvider);
      await callService.leaveCall(widget.call);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call ended: Screen recording detected'),
            backgroundColor: Colors.red,
          ),
        );
        
        // Navigate back
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('❌ [SECURITY] Error handling screen capture: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: Stack(
        children: [
          StreamCallContainer(
            call: widget.call,
            callConnectOptions: CallConnectOptions(
              camera: TrackOption.enabled(),
              microphone: TrackOption.enabled(),
              screenShare: TrackOption.disabled(), // Explicitly disabled
            ),
            onCallDisconnected: (CallDisconnectedProperties properties) {
              debugPrint('📞 [CALL] Call disconnected');
              debugPrint('   Reason: ${properties.reason}');
              _handleCallDisconnected(context, properties.reason);
            },
          ),
          // PHASE 5: Visual coin countdown timer (top of screen)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: _buildCoinTimer(scheme),
          ),
          // Show overlay if screen capture detected (iOS)
          if (_isScreenCaptured)
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.security,
                      size: 64,
                      color: Colors.white,
                    ),
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
