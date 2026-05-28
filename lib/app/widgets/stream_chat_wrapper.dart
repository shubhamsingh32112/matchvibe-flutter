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
import '../../features/home/services/presence_hydration_service.dart';
import '../../features/video/providers/stream_video_provider.dart';
import '../../core/utils/user_message_mapper.dart';

/// Wraps app with StreamChat widget and handles user connection
class StreamChatWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const StreamChatWrapper({super.key, required this.child});

  @override
  ConsumerState<StreamChatWrapper> createState() => _StreamChatWrapperState();
}

class _StreamChatWrapperState extends ConsumerState<StreamChatWrapper> {
  static const int _presenceBatchSize = 100;
  bool _isConnecting = false;
  bool _socketInitialized = false;
  int _connectGeneration = 0;

  bool _isConnectGenerationCurrent(int generation) =>
      mounted && generation == _connectGeneration;

  Future<void> _connectToStreamChat(AuthState authState) async {
    final generation = _connectGeneration;
    final firebaseUser = authState.firebaseUser!;
    final user = authState.user!;
    final creatorSafeAvatar = _resolveStreamAvatarUrl(user);

    final displayName =
        (user.username != null && user.username!.trim().isNotEmpty)
        ? user.username!
        : (user.email != null && user.email!.trim().isNotEmpty)
        ? user.email!
        : (user.phone != null && user.phone!.trim().isNotEmpty)
        ? user.phone!
        : 'User';

    final streamChatNotifier = ref.read(streamChatNotifierProvider.notifier);
    final streamVideoNotifier = ref.read(streamVideoProvider.notifier);
    final pushService = PushNotificationService();

    final chatFuture = () async {
      try {
        debugPrint('🔌 [STREAM WRAPPER] Connecting to Stream Chat...');
        final chatService = ChatService();
        final streamToken = await chatService.getChatToken();
        if (!_isConnectGenerationCurrent(generation)) return;

        await streamChatNotifier.connectUser(
          firebaseUid: firebaseUser.uid,
          username: displayName,
          avatarUrl: creatorSafeAvatar,
          streamToken: streamToken,
          mongoId: user.id,
          appRole: user.role,
          available: user.role == 'creator' || user.role == 'admin'
              ? true
              : null,
        );
        if (!_isConnectGenerationCurrent(generation)) return;

        final currentClient = ref.read(streamChatNotifierProvider);
        if (currentClient != null) {
          await pushService.initialize(currentClient);
        }
        debugPrint('✅ [STREAM WRAPPER] Stream Chat connected');
      } catch (e) {
        final readable = UserMessageMapper.userMessageFor(
          e,
          fallback: 'Chat is temporarily unavailable. Please retry shortly.',
        );
        debugPrint('❌ [STREAM WRAPPER] Failed to connect to Stream Chat: $readable');
      }
    }();

    final videoFuture = () async {
      try {
        debugPrint('🎥 [STREAM WRAPPER] Initializing Stream Video...');
        await streamVideoNotifier.initialize(
          userId: firebaseUser.uid,
          userName: displayName,
          userImage: creatorSafeAvatar,
        );
        if (!_isConnectGenerationCurrent(generation)) return;
        debugPrint('✅ [STREAM WRAPPER] Stream Video initialized');
      } catch (e) {
        debugPrint('❌ [STREAM WRAPPER] Failed to initialize Stream Video: $e');
      }
    }();

    await Future.wait([chatFuture, videoFuture]);
  }

  String? _resolveStreamAvatarUrl(dynamic user) {
    final urls = user.avatarAsset?.avatarUrls;
    final candidates = <String?>[urls?.callPhoto, urls?.md, urls?.feedTile];
    for (final candidate in candidates) {
      if (candidate == null) continue;
      final trimmed = candidate.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  void _bootstrapPresenceSockets(String? token) {
    if (token == null || token.isEmpty) {
      debugPrint(
        '⚠️  [STREAM WRAPPER] Skipping SocketService bootstrap — no token',
      );
      return;
    }

    final generation = _connectGeneration;
    final socketService = ref.read(socketServiceProvider);
    final user = ref.read(authProvider).user;
    final role = user?.role;
    final presenceHydration = ref.read(presenceHydrationServiceProvider);

    try {
      socketService.connect(token);
    } catch (e) {
      debugPrint('⚠️  [STREAM WRAPPER] SocketService.connect failed: $e');
    }

    if (role != 'creator') {
      Future<void>(() async {
        if (!_isConnectGenerationCurrent(generation)) return;
        await _hydrateFanCreatorPresenceFast(generation);
        if (!_isConnectGenerationCurrent(generation)) return;
        try {
          final ids = await presenceHydration.collectCreatorFirebaseUids();
          if (!_isConnectGenerationCurrent(generation)) return;
          _requestCreatorAvailabilityInChunks(ids);
        } catch (e) {
          debugPrint(
            '⚠️  [STREAM WRAPPER] Creator sweep hydration failed, falling back to first page: $e',
          );
          if (!_isConnectGenerationCurrent(generation)) return;
          await _fallbackCreatorHydration(generation);
        }
      });
    }

    if (role == 'creator' || role == 'admin') {
      Future<void>(() async {
        try {
          if (!_isConnectGenerationCurrent(generation)) return;
          final ids = await presenceHydration.collectUserFirebaseUids();
          if (!_isConnectGenerationCurrent(generation)) return;
          _requestUserAvailabilityInChunks(ids);
        } catch (e) {
          debugPrint(
            '⚠️  [STREAM WRAPPER] User sweep hydration failed, falling back to first page: $e',
          );
          if (!_isConnectGenerationCurrent(generation)) return;
          await _fallbackUserHydration(generation);
        }
      });
    }
  }

  /// Phase A: hydrate creators already visible on the home feed (no /creator/uids wait).
  Future<void> _hydrateFanCreatorPresenceFast(int generation) async {
    try {
      final creators = await ref.read(creatorsProvider.future);
      if (!_isConnectGenerationCurrent(generation)) return;
      final ids = <String>[
        for (final c in creators)
          if (c.firebaseUid != null && c.firebaseUid!.isNotEmpty) c.firebaseUid!,
      ];
      if (ids.isNotEmpty) {
        _requestCreatorAvailabilityInChunks(ids);
      }
    } catch (_) {
      // Feed may not be loaded yet; full UID sweep runs after.
    }
  }

  void _requestCreatorAvailabilityInChunks(List<String> ids) {
    if (ids.isEmpty) return;
    final socketService = ref.read(socketServiceProvider);
    for (var i = 0; i < ids.length; i += _presenceBatchSize) {
      final end = (i + _presenceBatchSize > ids.length)
          ? ids.length
          : i + _presenceBatchSize;
      socketService.requestAvailability(ids.sublist(i, end));
    }
  }

  void _requestUserAvailabilityInChunks(List<String> ids) {
    if (ids.isEmpty) return;
    final socketService = ref.read(socketServiceProvider);
    for (var i = 0; i < ids.length; i += _presenceBatchSize) {
      final end = (i + _presenceBatchSize > ids.length)
          ? ids.length
          : i + _presenceBatchSize;
      socketService.requestUserAvailability(ids.sublist(i, end));
    }
  }

  Future<void> _fallbackCreatorHydration(int generation) async {
    final creators = await ref.read(creatorsProvider.future);
    if (!_isConnectGenerationCurrent(generation)) return;
    final ids = creators
        .where((c) => c.firebaseUid != null && c.firebaseUid!.isNotEmpty)
        .map((c) => c.firebaseUid!)
        .toList();
    _requestCreatorAvailabilityInChunks(ids);
  }

  Future<void> _fallbackUserHydration(int generation) async {
    final users = await ref.read(usersProvider.future);
    if (!_isConnectGenerationCurrent(generation)) return;
    final ids = users
        .where((u) => u.firebaseUid != null && u.firebaseUid!.isNotEmpty)
        .map((u) => u.firebaseUid!)
        .toList();
    _requestUserAvailabilityInChunks(ids);
  }

  @override
  Widget build(BuildContext context) {
    final authReady = ref.watch(
      authProvider.select(
        (s) => s.isAuthenticated &&
            s.firebaseUser != null &&
            s.user != null,
      ),
    );
    final firebaseUser = ref.watch(
      authProvider.select((s) => s.firebaseUser),
    );
    final streamClient = ref.watch(streamChatNotifierProvider);

    if (!_socketInitialized && authReady && firebaseUser != null) {
      _socketInitialized = true;
      firebaseUser
          .getIdToken()
          .then((token) {
            if (!context.mounted) return;
            _bootstrapPresenceSockets(token);
          })
          .catchError((e) async {
            debugPrint(
              '⚠️ [STREAM WRAPPER] Failed to get Firebase token for socket: $e',
            );
            if (!mounted) return;
            final prefs = await SharedPreferences.getInstance();
            if (!context.mounted) return;
            final cached = prefs.getString(AppConstants.keyAuthToken);
            if (cached != null && cached.isNotEmpty) {
              _bootstrapPresenceSockets(cached);
            } else {
              debugPrint(
                '⚠️ [STREAM WRAPPER] No cached token — presence sockets require sign-in',
              );
            }
          });
    }

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.isAuthenticated && !_isConnecting) {
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

      if (!next.isAuthenticated) {
        _connectGeneration++;
        PushNotificationService().dispose();

        final streamChatNotifier = ref.read(streamChatNotifierProvider.notifier);
        final currentClient = ref.read(streamChatNotifierProvider);
        if (currentClient?.state.currentUser != null) {
          streamChatNotifier.disconnectUser();
        }

        final videoClient = ref.read(streamVideoProvider);
        if (videoClient != null) {
          ref.read(streamVideoProvider.notifier).disconnect();
        }

        final prevUser = prev?.user;
        final wasCreator = prevUser != null &&
            (prevUser.role == 'creator' || prevUser.role == 'admin');
        ref.read(socketServiceProvider).disconnect(
              emitPresenceOffline: true,
              isCreator: wasCreator,
            );
        _socketInitialized = false;
      }
    });

    if (authReady &&
        streamClient?.state.currentUser == null &&
        !_isConnecting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !ref.read(authProvider).isAuthenticated ||
            ref.read(streamChatNotifierProvider)?.state.currentUser != null ||
            _isConnecting) {
          return;
        }
        _isConnecting = true;
        final authState = ref.read(authProvider);
        _connectToStreamChat(authState).whenComplete(() {
          if (mounted) {
            _isConnecting = false;
          }
        });
      });
    }

    return widget.child;
  }
}
