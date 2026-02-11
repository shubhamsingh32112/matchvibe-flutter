import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:logging/logging.dart';
import '../services/chat_service.dart';
import '../../../core/constants/app_constants.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

/// Stream Chat client provider
final streamChatClientProvider = Provider<StreamChatClient?>((ref) {
  // Client will be initialized when user logs in
  return null;
});

/// Stream Chat client state notifier
class StreamChatNotifier extends StateNotifier<StreamChatClient?> {
  StreamChatNotifier() : super(
    // CRITICAL: Initialize client immediately so StreamChat can always wrap the app
    // This ensures StreamChat is in the widget tree from the start
    StreamChatClient(
      AppConstants.streamApiKey,
      logLevel: kDebugMode ? Level.INFO : Level.OFF,
    ),
  );

  /// Initialize and connect user to Stream Chat
  Future<void> connectUser({
    required String firebaseUid,
    required String username,
    String? avatarUrl,
    required String streamToken,
    String? appRole, // 'user' | 'creator' | 'admin'
    bool? available, // For creators: whether they want to accept calls
  }) async {
    try {
      if (state == null) {
        throw StateError('StreamChatClient not initialized');
      }

      debugPrint('🔌 [STREAM] Connecting user to Stream Chat...');
      debugPrint('   User ID: $firebaseUid');
      debugPrint('   Username: $username');
      debugPrint('   App Role: $appRole');
      debugPrint('   Available: $available');

      // Connect user (client already exists)
      // Note: Presence (online/offline) is automatic via WebSocket connection
      // We set 'available' in extraData for creators (business intent)
      await state!.connectUser(
        User(
          id: firebaseUid,
          name: username,
          image: avatarUrl,
          extraData: {
            if (appRole != null) 'appRole': appRole,
            if (available != null) 'available': available,
          },
        ),
        streamToken,
      );

      debugPrint('✅ [STREAM] User connected to Stream Chat');
    } catch (e) {
      debugPrint('❌ [STREAM] Error connecting user: $e');
      rethrow;
    }
  }

  /// Disconnect user from Stream Chat
  Future<void> disconnectUser() async {
    try {
      if (state != null && state!.state.currentUser != null) {
        debugPrint('🔌 [STREAM] Disconnecting user...');
        await state!.disconnectUser();
        debugPrint('✅ [STREAM] User disconnected');
        // Note: We keep the client instance (don't set state to null)
        // This ensures StreamChat widget remains in the tree
      }
    } catch (e) {
      debugPrint('❌ [STREAM] Error disconnecting user: $e');
    }
  }
}

final streamChatNotifierProvider =
    StateNotifierProvider<StreamChatNotifier, StreamChatClient?>((ref) {
  return StreamChatNotifier();
});
