import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

/// Service for managing video calls
/// 
/// IMPORTANT: Stream Video is SDK-first. Calls MUST be created via SDK (getOrCreate),
/// NOT via REST API. This ensures proper call lifecycle, ringing, SFU sessions, etc.
class CallService {
  /// Initiate a call to a creator
  /// 
  /// [creatorFirebaseUid] - Creator's Firebase UID (Stream user ID)
  /// [currentUserFirebaseUid] - Current user's Firebase UID
  /// [creatorMongoId] - Creator's MongoDB ObjectId (for deterministic callId)
  /// 
  /// Returns the Call object ready to join
  /// 
  /// This replaces the old REST-based approach. Call creation is now done entirely
  /// via the Stream Video SDK, which handles:
  /// - Call creation
  /// - Role assignment (admin for caller, call_member for callee)
  /// - Ringing
  /// - SFU session creation
  /// - Push/VoIP notifications
  Future<Call> initiateCall({
    required String creatorFirebaseUid,
    required String currentUserFirebaseUid,
    required String creatorMongoId,
    required StreamVideo streamVideo,
  }) async {
    try {
      debugPrint('📞 [CALL] Initiating call to creator: $creatorFirebaseUid');

      // Generate a unique call ID per attempt.
      // Appending a timestamp ensures that each call creates a fresh session
      // in Stream Video. Without this, getOrCreate would return the stale
      // (ended/disconnected) call object from a previous session, preventing
      // the user from ever calling the same creator again.
      // NOTE: Stream Video enforces a 64-char max on call IDs.
      //   Firebase UID (28) + '_' + Mongo ID (24) + '_' + seconds (10) = 63 chars.
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000; // seconds
      final callId = '${currentUserFirebaseUid}_${creatorMongoId}_$ts';

      debugPrint('📞 [CALL] Call ID: $callId');

      // Create call object using Stream SDK
      final call = streamVideo.makeCall(
        callType: StreamCallType.defaultType(),
        id: callId,
      );

      debugPrint('✅ [CALL] Call object created');

      // Get or create call with ringing enabled
      // This single call replaces the entire REST endpoint:
      // - Creates the call if it doesn't exist
      // - Adds members (creator gets call_member role automatically)
      // - Enables ringing
      // - Opens SFU session
      // - Sends push/VoIP notification to creator
      await call.getOrCreate(
        memberIds: [creatorFirebaseUid], // Add creator to call (will receive incoming call event)
        ringing: true, // Enable ringing
        video: true, // Video call
      );

      debugPrint('✅ [CALL] Call created with ringing enabled');

      return call;
    } catch (e) {
      debugPrint('❌ [CALL] Error initiating call: $e');
      rethrow;
    }
  }

  /// Join an existing call with retry logic
  /// 
  /// 🔥 FIX 14: Added exponential backoff retry logic
  /// - Attempts to join with exponential backoff (1s, 2s, 4s)
  /// - Max 3 retries by default
  /// - Still fire-and-forget (doesn't block UI)
  /// - UI should react to call.state changes
  /// 
  /// [maxRetries] - Maximum number of retry attempts (default: 3)
  /// [initialDelay] - Initial delay in seconds before first retry (default: 1)
  void joinCall(Call call, {int maxRetries = 3, int initialDelay = 1}) {
    debugPrint('📞 [CALL] Joining call: ${call.id} (with retry logic, maxRetries: $maxRetries)');
    
    _joinCallWithRetry(call, maxRetries: maxRetries, initialDelay: initialDelay);
  }

  /// Internal method to join call with exponential backoff retry
  Future<void> _joinCallWithRetry(
    Call call, {
    int maxRetries = 3,
    int initialDelay = 1,
    int attempt = 0,
  }) async {
    try {
      await call.join();
      debugPrint('✅ [CALL] Join completed successfully (attempt ${attempt + 1})');
    } catch (error) {
      final currentAttempt = attempt + 1;
      debugPrint('❌ [CALL] Error joining call (attempt $currentAttempt/$maxRetries): $error');
      
      // If we've exhausted retries, log and let the error propagate
      if (currentAttempt >= maxRetries) {
        debugPrint('❌ [CALL] Max retries ($maxRetries) reached. Giving up.');
        // Error is handled by call screen via call.state stream
        return;
      }
      
      // Calculate exponential backoff delay: initialDelay * 2^attempt
      // e.g., attempt 0: 1s, attempt 1: 2s, attempt 2: 4s
      final delaySeconds = initialDelay * math.pow(2, attempt).toInt();
      debugPrint('🔄 [CALL] Retrying in ${delaySeconds}s...');
      
      // Wait before retrying
      await Future.delayed(Duration(seconds: delaySeconds));
      
      // Recursive retry
      await _joinCallWithRetry(
        call,
        maxRetries: maxRetries,
        initialDelay: initialDelay,
        attempt: currentAttempt,
      );
    }
  }

  /// Leave/end a call
  Future<void> leaveCall(Call call) async {
    try {
      debugPrint('📞 [CALL] Leaving call: ${call.id}');
      await call.leave();
      debugPrint('✅ [CALL] Left call successfully');
    } catch (e) {
      debugPrint('❌ [CALL] Error leaving call: $e');
      rethrow;
    }
  }
}

final callServiceProvider = Provider<CallService>((ref) {
  return CallService();
});
