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

  /// Join an existing call (fire-and-forget)
  /// 
  /// 🔥 CRITICAL: This is fire-and-forget. Do NOT await this.
  /// Stream SDK handles retries internally. UI should react to call.state changes.
  void joinCall(Call call) {
    debugPrint('📞 [CALL] Joining call: ${call.id} (fire-and-forget)');
    call.join().then((_) {
      debugPrint('✅ [CALL] Join completed successfully');
    }).catchError((error) {
      debugPrint('❌ [CALL] Error joining call: $error');
      // Error is handled by call screen via call.state stream
    });
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
