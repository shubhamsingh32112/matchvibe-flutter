import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../app/widgets/main_layout.dart';
import '../../../shared/models/profile_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/home_provider.dart';
import '../../user/providers/user_availability_provider.dart';
import '../services/chat_service.dart';
import '../utils/chat_utils.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen>
    with SingleTickerProviderStateMixin {
  StreamChannelListController? _controller;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final streamChat = StreamChat.maybeOf(context);
      if (streamChat != null && streamChat.client.state.currentUser != null) {
        setState(() {
          _controller = StreamChannelListController(
            client: streamChat.client,
            filter: Filter.and([
              Filter.equal('type', 'messaging'),
              Filter.in_(
                'members',
                [streamChat.client.state.currentUser!.id],
              ),
              Filter.exists('last_message_at'),
            ]),
            channelStateSort: const [SortOption('last_message_at')],
          );
        });
      }

      // Create tab controller for creators
      final authState = ref.read(authProvider);
      final isCreator = authState.user?.role == 'creator' ||
          authState.user?.role == 'admin';
      if (isCreator && _tabController == null) {
        _tabController = TabController(length: 2, vsync: this);
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  void _onChannelTap(Channel channel) {
    final channelId = channel.id;
    context.push('/chat/$channelId');
  }

  @override
  Widget build(BuildContext context) {
    final streamChat = StreamChat.maybeOf(context);
    final authState = ref.watch(authProvider);
    final isCreator = authState.user?.role == 'creator' ||
        authState.user?.role == 'admin';

    // Wait for StreamChat to be ready
    if (streamChat == null || streamChat.client.state.currentUser == null) {
      return MainLayout(
        selectedIndex: 2,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Initialize controller if not ready
    if (_controller == null) {
      _initializeController();
      return MainLayout(
        selectedIndex: 2,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Initialize tab controller for creators if not ready
    if (isCreator && _tabController == null) {
      _tabController = TabController(length: 2, vsync: this);
    }

    // ── Creator view: two tabs ───────────────────────────────────────────
    if (isCreator && _tabController != null) {
      return MainLayout(
        selectedIndex: 2,
        child: Scaffold(
          body: Column(
            children: [
              // Tab bar
              Material(
                color: Theme.of(context).colorScheme.surface,
                child: TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  tabs: const [
                    Tab(text: 'Recent Chats'),
                    Tab(text: 'Online Users'),
                  ],
                ),
              ),
              // Tab views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Recent chats
                    _controller != null
                        ? _RecentChatsTab(
                            controller: _controller!,
                            onChannelTap: _onChannelTap,
                          )
                        : const Center(child: CircularProgressIndicator()),
                    // Tab 2: Online users
                    const _OnlineUsersTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Regular user view: just recent chats ─────────────────────────────
    return MainLayout(
      selectedIndex: 2,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () => _controller!.refresh(),
          child: StreamChannelListView(
            controller: _controller!,
            onChannelTap: _onChannelTap,
            emptyBuilder: (context) => _buildEmptyState(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: AppPalette.emptyIcon,
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              color: AppPalette.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation after a video call',
            style: TextStyle(
              fontSize: 14,
              color: AppPalette.subtitle,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Tab 1 — Recent Chats (existing Stream channel list)
// ═════════════════════════════════════════════════════════════════════════════

class _RecentChatsTab extends StatelessWidget {
  final StreamChannelListController controller;
  final void Function(Channel) onChannelTap;

  const _RecentChatsTab({
    required this.controller,
    required this.onChannelTap,
  });

  @override
  Widget build(BuildContext context) {
    final streamChat = StreamChat.maybeOf(context);
    final currentUserId = streamChat?.client.state.currentUser?.id;
    
    return RefreshIndicator(
      onRefresh: () => controller.refresh(),
      child: StreamChannelListView(
        controller: controller,
        onChannelTap: onChannelTap,
        // Custom item builder to show other user's name (not channel name)
        itemBuilder: currentUserId != null
            ? (context, channels, index, defaultTile) {
                final channel = channels[index];
                // Get the other user's display name
                final otherUserName = getOtherUserDisplayName(channel, currentUserId);
                final otherUser = getOtherUserFromChannel(channel, currentUserId);
                final otherUserImage = otherUser?.image;
                
                // Use StreamChannelListTile but customize the title to show other user's name
                return StreamChannelListTile(
                  channel: channel,
                  onTap: () => onChannelTap(channel),
                  title: Text(
                    otherUserName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  leading: otherUserImage != null
                      ? CircleAvatar(
                          backgroundImage: NetworkImage(otherUserImage),
                          radius: 20,
                        )
                      : CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.person,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                          radius: 20,
                        ),
                );
              }
            : null,
        emptyBuilder: (context) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: AppPalette.emptyIcon,
              ),
              const SizedBox(height: 16),
              Text(
                'No conversations yet',
                style: TextStyle(
                  fontSize: 18,
                  color: AppPalette.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Users will appear here after they message you',
                style: TextStyle(
                  fontSize: 14,
                  color: AppPalette.subtitle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Tab 2 — Online Users (all users list with chat action)
// ═════════════════════════════════════════════════════════════════════════════

class _OnlineUsersTab extends ConsumerStatefulWidget {
  const _OnlineUsersTab();

  @override
  ConsumerState<_OnlineUsersTab> createState() => _OnlineUsersTabState();
}

class _OnlineUsersTabState extends ConsumerState<_OnlineUsersTab> {
  final Set<String> _loadingUserIds = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onUserListScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onUserListScroll)
      ..dispose();
    super.dispose();
  }

  void _onUserListScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 500) return;
    final meta = ref.read(usersFeedMetaProvider);
    if (meta.hasMore && !meta.isLoadingMore) {
      ref.read(usersProvider.notifier).loadMore();
    }
  }

  Future<void> _openChat(UserProfileModel user) async {
    if (_loadingUserIds.contains(user.id)) return;

    setState(() => _loadingUserIds.add(user.id));

    try {
      final chatService = ChatService();
      // Backend accepts MongoDB ID — resolves to Firebase UID internally
      final result = await chatService.createOrGetChannel(user.id);
      final channelId = result['channelId'] as String?;

      if (channelId != null && mounted) {
        context.push('/chat/$channelId');
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          UserMessageMapper.userMessageFor(
            e,
            fallback: 'Couldn\'t open chat. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingUserIds.remove(user.id));
    }
  }


  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);
    final usersMeta = ref.watch(usersFeedMetaProvider);
    final userAvailabilityMap = ref.watch(userAvailabilityProvider);
    final scheme = Theme.of(context).colorScheme;

    return usersAsync.when(
      data: (users) {
        final dedupedUsersByKey = <String, UserProfileModel>{};
        for (final user in users) {
          final key = user.id.isNotEmpty
              ? user.id
              : (user.firebaseUid ?? '');
          if (key.isEmpty) continue;
          dedupedUsersByKey[key] = user;
        }
        final dedupedUsers = dedupedUsersByKey.values.toList(growable: false);

        // Only users with explicit socket state "online" (Redis/API does not add rows here).
        final onlineUsers = dedupedUsers.where((user) {
          if (user.firebaseUid == null) return false;
          return userAvailabilityMap[user.firebaseUid] ==
              UserAvailability.online;
        }).toList();

        if (onlineUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline,
                    size: 64, color: AppPalette.emptyIcon),
                const SizedBox(height: 16),
                Text(
                  'No online users',
                  style: TextStyle(
                    fontSize: 18,
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Users will appear here when they come online',
                  style: TextStyle(fontSize: 14, color: AppPalette.subtitle),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.read(usersProvider.notifier).refreshFeed(),
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: onlineUsers.length + (usersMeta.hasMore ? 1 : 0),
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.3)),
            itemBuilder: (context, index) {
              if (index >= onlineUsers.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              final user = onlineUsers[index];
              final isLoading = _loadingUserIds.contains(user.id);

              return ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: scheme.primaryContainer,
                  backgroundImage: user.avatar != null &&
                          (user.avatar!.startsWith('http') ||
                              user.avatar!.startsWith('data:'))
                      ? NetworkImage(user.avatar!)
                      : null,
                  child: user.avatar == null ||
                          (!user.avatar!.startsWith('http') &&
                              !user.avatar!.startsWith('data:'))
                      ? Icon(Icons.person,
                          color: scheme.onPrimaryContainer, size: 24)
                      : null,
                ),
                title: Text(
                  user.username ?? 'User',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppPalette.success,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                trailing: SizedBox(
                  width: 40,
                  height: 40,
                  child: Material(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: isLoading ? null : () => _openChat(user),
                      borderRadius: BorderRadius.circular(999),
                      child: Center(
                        child: isLoading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      scheme.primary),
                                ),
                              )
                            : Icon(
                                Icons.chat_bubble_outline,
                                size: 20,
                                color: scheme.primary,
                              ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load users',
              style: TextStyle(fontSize: 16, color: scheme.onSurface),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.read(usersProvider.notifier).refreshFeed(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
