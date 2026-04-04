import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/push_notification_service.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/chat/providers/stream_chat_provider.dart';
import '../../features/chat/services/chat_service.dart';
import '../../features/home/providers/availability_provider.dart';
import '../../features/home/providers/home_provider.dart';
import '../../features/video/providers/stream_video_provider.dart';
import '../../core/services/availability_socket_service.dart';

/// Wraps app with StreamChat widget and handles user connection
class StreamChatWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const StreamChatWrapper({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<StreamChatWrapper> createState() => _StreamChatWrapperState();
}

class _StreamChatWrapperState extends ConsumerState<StreamChatWrapper> {
  bool _isConnecting = false;
  bool _socketInitialized = false; // ⚠️ Guard: prevent re-init on every rebuild

  bool _isNetworkLike(String? value) {
    if (value == null || value.isEmpty) return false;
    return value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('data:');
  }

  Future<void> _connectToStreamChat(AuthState authState) async {
    // Extract variables at method level so they're accessible to both try-catch blocks
    final firebaseUser = authState.firebaseUser!;
    final user = authState.user!;
    final isCreatorRole =
        user.role == 'creator' || user.role == 'admin';
    final creatorSafeAvatar =
        isCreatorRole ? (_isNetworkLike(user.avatar) ? user.avatar : null) : user.avatar;

    // Calculate display name once (used by both Stream Chat and Stream Video)
    final displayName = (user.username != null && user.username!.trim().isNotEmpty)
        ? user.username!
        : (user.email != null && user.email!.trim().isNotEmpty)
            ? user.email!
            : (user.phone != null && user.phone!.trim().isNotEmpty)
                ? user.phone!
                : 'User';

    // Connect to Stream Chat
    try {
      debugPrint('🔌 [STREAM WRAPPER] Connecting to Stream Chat...');
      debugPrint('   User ID: ${firebaseUser.uid}');
      debugPrint('   Display Name: $displayName');

      // Get Stream Chat token from backend
      final chatService = ChatService();
      final streamToken = await chatService.getChatToken();
      
      await ref.read(streamChatNotifierProvider.notifier).connectUser(
            firebaseUid: firebaseUser.uid,
            username: displayName,
            avatarUrl: creatorSafeAvatar,
            streamToken: streamToken,
            mongoId: user.id,
            appRole: user.role, // Pass app role to Stream
            available: user.role == 'creator' || user.role == 'admin' 
                ? true // Creators should be available while app is running
                : null, // Regular users don't have available flag
          );

      debugPrint('✅ [STREAM WRAPPER] Stream Chat connected');

      // Register FCM device for push notifications
      final currentClient = ref.read(streamChatNotifierProvider);
      if (currentClient != null) {
        final outsideAppNotificationsAllowed =
            user.role == 'creator' || user.role == 'admin';
        await PushNotificationService().initialize(
          currentClient,
          enableOutsideAppNotifications: outsideAppNotificationsAllowed,
        );
      }
    } catch (e) {
      debugPrint('❌ [STREAM WRAPPER] Failed to connect to Stream Chat: $e');
      // Don't block app if Stream Chat fails
    }

    // Initialize Stream Video
    try {
      debugPrint('🎥 [STREAM WRAPPER] Initializing Stream Video...');
      
      await ref.read(streamVideoProvider.notifier).initialize(
        userId: firebaseUser.uid,
        userName: displayName,
        userImage: creatorSafeAvatar,
      );

      debugPrint('✅ [STREAM WRAPPER] Stream Video initialized');
    } catch (e) {
      debugPrint('❌ [STREAM WRAPPER] Failed to initialize Stream Video: $e');
      // Don't block app if Stream Video fails
    }

    // 🔥 Presence + billing Socket.IO bootstrap happens in build() after getIdToken.
  }

  /// Connects [SocketService] as soon as the user is authenticated (not only on HomeScreen)
  /// so creator/user presence and billing stay real-time on every tab.
  void _bootstrapPresenceSockets(String? token) {
    if (token == null || token.isEmpty) {
      debugPrint('⚠️  [STREAM WRAPPER] Skipping SocketService bootstrap — no token');
      return;
    }
    try {
      ref.read(socketServiceProvider).connect(token);
    } catch (e) {
      debugPrint('⚠️  [STREAM WRAPPER] SocketService.connect failed: $e');
    }

    final user = ref.read(authProvider).user;
    final role = user?.role;

    // Fans / admins: hydrate creator Redis map via one batch (then live creator:status).
    if (role != 'creator') {
      Future<void>(() async {
        try {
          final creators = await ref.read(creatorsProvider.future);
          if (!mounted) return;
          final ids = creators
              .where((c) => c.firebaseUid != null && c.firebaseUid!.isNotEmpty)
              .map((c) => c.firebaseUid!)
              .toList();
          if (ids.isNotEmpty) {
            ref.read(socketServiceProvider).requestAvailability(ids);
          }
        } catch (e) {
          debugPrint('⚠️  [STREAM WRAPPER] Creator availability hydrate: $e');
        }
      });
    }

    // Creators / admins: hydrate fan Redis map (then live user:status on SocketService).
    if (role == 'creator' || role == 'admin') {
      Future<void>(() async {
        try {
          final users = await ref.read(usersProvider.future);
          if (!mounted) return;
          final ids = users
              .where((u) => u.firebaseUid != null && u.firebaseUid!.isNotEmpty)
              .map((u) => u.firebaseUid!)
              .toList();
          if (ids.isNotEmpty) {
            ref.read(socketServiceProvider).requestUserAvailability(ids);
          }
        } catch (e) {
          debugPrint('⚠️  [STREAM WRAPPER] User availability hydrate: $e');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final streamClient = ref.watch(streamChatNotifierProvider);

    // 🔥 FIX 1 & 3: Initialize Socket.IO when authenticated (with auth token for authentication)
    // ⚠️ Guard: only init once – do NOT re-init on every widget rebuild,
    // because that would re-seed and could fire getIdToken() on every frame.
    if (!_socketInitialized && authState.isAuthenticated && authState.firebaseUser != null && authState.user != null) {
      _socketInitialized = true;
      final isCreator = authState.user!.role == 'creator' || authState.user!.role == 'admin';
      
      // Get Firebase ID token for socket authentication
      // This runs asynchronously but socket service handles pending auth gracefully
      authState.firebaseUser!.getIdToken().then((token) {
        if (!context.mounted) return;
        AvailabilitySocketService.instance.init(
          context,
          authToken: token,
          creatorId: isCreator ? authState.firebaseUser!.uid : null,
          isCreator: isCreator,
        );
        _bootstrapPresenceSockets(token);
      }).catchError((e) async {
        debugPrint('⚠️ [STREAM WRAPPER] Failed to get Firebase token for socket: $e');
        if (!mounted) return;
        final prefs = await SharedPreferences.getInstance();
        if (!context.mounted) return;
        final cached = prefs.getString(AppConstants.keyAuthToken);
        if (cached != null && cached.isNotEmpty) {
          AvailabilitySocketService.instance.init(
            context,
            authToken: cached,
            creatorId: isCreator ? authState.firebaseUser!.uid : null,
            isCreator: isCreator,
          );
          _bootstrapPresenceSockets(cached);
        } else {
          debugPrint('⚠️ [STREAM WRAPPER] No cached token — presence sockets require sign-in');
        }
      });
    }

    // React to auth state changes (using ref.listen in build - this is the correct place)
    ref.listen<AuthState>(authProvider, (prev, next) {
      // If user is authenticated but Stream Chat is not connected
      if (next.isAuthenticated && !_isConnecting) {
        // Check if user is already connected (read fresh value inside callback)
        final currentClient = ref.read(streamChatNotifierProvider);
        if (currentClient?.state.currentUser == null) {
          _isConnecting = true;
          _connectToStreamChat(next).whenComplete(() {
            if (mounted) {
              _isConnecting = false;
            }
          });
        }
      }

      // If user logged out, disconnect Stream Chat, Stream Video, and Availability Socket
      if (!next.isAuthenticated) {
        // Remove FCM device from Stream before disconnecting
        PushNotificationService().dispose();

        final currentClient = ref.read(streamChatNotifierProvider);
        if (currentClient?.state.currentUser != null) {
          ref.read(streamChatNotifierProvider.notifier).disconnectUser();
        }
        
        // Disconnect Stream Video
        final videoClient = ref.read(streamVideoProvider);
        if (videoClient != null) {
          ref.read(streamVideoProvider.notifier).disconnect();
        }
        
        // 🔥 Disconnect Availability Socket + billing/presence SocketService
        AvailabilitySocketService.instance.dispose();
        ref.read(socketServiceProvider).disconnect();
        _socketInitialized = false; // ⚠️ Reset so next login can re-init
      }
    });

    // Handle initial state: if user is already authenticated on first build
    if (authState.isAuthenticated && streamClient?.state.currentUser == null && !_isConnecting) {
      // Use post-frame callback to avoid calling async in build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && 
            ref.read(authProvider).isAuthenticated && 
            ref.read(streamChatNotifierProvider)?.state.currentUser == null && 
            !_isConnecting) {
          _isConnecting = true;
          _connectToStreamChat(ref.read(authProvider)).whenComplete(() {
            if (mounted) {
              _isConnecting = false;
            }
          });
        }
      });
    }

    // Just return child - StreamChat wrapping happens in MaterialApp.router builder
    return widget.child;
  }
}
