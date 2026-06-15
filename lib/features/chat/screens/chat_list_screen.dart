import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/image_precache_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../app/widgets/app_nav_destinations.dart';
import '../../../app/widgets/app_nav_index.dart';
import '../../../app/widgets/main_layout.dart';
import '../../../core/config/app_config_provider.dart';
import '../../../shared/models/profile_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../recent/widgets/recent_calls_tab.dart';
import '../../user/providers/online_users_provider.dart';
import '../services/chat_service.dart';
import '../utils/chat_utils.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const ChatListScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen>
    with TickerProviderStateMixin {
  StreamChannelListController? _controller;
  TabController? _creatorTabController;
  TabController? _userTabController;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _creatorTabController?.dispose();
    _userTabController?.dispose();
    super.dispose();
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

      final authState = ref.read(authProvider);
      final isCreator = authState.user?.role == 'creator' ||
          authState.user?.role == 'admin';
      final isUser = authState.user?.role == 'user';
      final features = ref.read(appFeaturesProvider);
      final showUserChatSubTabs = isUser &&
          !AppNavDestinations.showRecentsInNav(features, authState.user?.role);

      if (isCreator && _creatorTabController == null) {
        _creatorTabController = TabController(length: 2, vsync: this);
      }
      if (showUserChatSubTabs && _userTabController == null) {
        final tabIndex = widget.initialTabIndex.clamp(0, 1);
        _userTabController = TabController(
          length: 2,
          vsync: this,
          initialIndex: tabIndex,
        );
      }
    });
  }

  void _onChannelTap(Channel channel) {
    final channelId = channel.id;
    context.push('/chat/$channelId');
  }

  @override
  Widget build(BuildContext context) {
    final streamChat = StreamChat.maybeOf(context);
    final userRole = ref.watch(authProvider.select((s) => s.user?.role));
    final features = ref.watch(appFeaturesProvider);
    final isCreator =
        userRole == 'creator' || userRole == 'admin';
    final isUser = userRole == 'user';
    final showUserChatSubTabs =
        isUser && !AppNavDestinations.showRecentsInNav(features, userRole);

    if (streamChat == null || streamChat.client.state.currentUser == null) {
      return MainLayout(
        selectedIndex: appNavSelectedIndex(ref, '/chat-list'),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_controller == null) {
      _initializeController();
      return MainLayout(
        selectedIndex: appNavSelectedIndex(ref, '/chat-list'),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (isCreator && _creatorTabController == null) {
      _creatorTabController = TabController(length: 2, vsync: this);
    }
    if (showUserChatSubTabs && _userTabController == null) {
      final tabIndex = widget.initialTabIndex.clamp(0, 1);
      _userTabController = TabController(
        length: 2,
        vsync: this,
        initialIndex: tabIndex,
      );
    }

    if (isCreator && _creatorTabController != null) {
      return MainLayout(
        selectedIndex: appNavSelectedIndex(ref, '/chat-list'),
        child: Scaffold(
          body: Column(
            children: [
              Material(
                color: Theme.of(context).colorScheme.surface,
                child: TabBar(
                  controller: _creatorTabController,
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
              Expanded(
                child: TabBarView(
                  controller: _creatorTabController,
                  children: [
                    _controller != null
                        ? _RecentChatsTab(
                            controller: _controller!,
                            onChannelTap: _onChannelTap,
                          )
                        : const Center(child: CircularProgressIndicator()),
                    const _OnlineUsersTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (showUserChatSubTabs && _userTabController != null) {
      return MainLayout(
        selectedIndex: appNavSelectedIndex(ref, '/chat-list'),
        child: Scaffold(
          body: Column(
            children: [
              Material(
                color: Theme.of(context).colorScheme.surface,
                child: TabBar(
                  controller: _userTabController,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  tabs: const [
                    Tab(text: 'Chats'),
                    Tab(text: 'Recent Calls'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _userTabController,
                  children: [
                    _RecentChatsChannelList(
                      controller: _controller!,
                      onChannelTap: _onChannelTap,
                      emptyBuilder: (context) => _buildEmptyState(),
                    ),
                    const RecentCallsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return MainLayout(
      selectedIndex: appNavSelectedIndex(ref, '/chat-list'),
      child: Scaffold(
        body: _RecentChatsChannelList(
          controller: _controller!,
          onChannelTap: _onChannelTap,
          emptyBuilder: (context) => _buildEmptyState(),
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

class _RecentChatsChannelList extends StatelessWidget {
  final StreamChannelListController controller;
  final void Function(Channel) onChannelTap;
  final Widget Function(BuildContext context) emptyBuilder;

  const _RecentChatsChannelList({
    required this.controller,
    required this.onChannelTap,
    required this.emptyBuilder,
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
        itemBuilder: currentUserId != null
            ? (context, channels, index, defaultTile) {
                final channel = channels[index];
                final otherUserName =
                    getOtherUserDisplayName(channel, currentUserId);
                final otherUser =
                    getOtherUserFromChannel(channel, currentUserId);
                final otherUserImage = otherUser?.image;

                return StreamChannelListTile(
                  channel: channel,
                  onTap: () => onChannelTap(channel),
                  title: Text(
                    otherUserName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  leading: AppAvatar(
                    size: 40,
                    imageUrlOverride: otherUserImage,
                    fallbackText: otherUserName.isNotEmpty
                        ? otherUserName[0]
                        : 'U',
                  ),
                );
              }
            : null,
        emptyBuilder: emptyBuilder,
      ),
    );
  }
}

class _RecentChatsTab extends StatelessWidget {
  final StreamChannelListController controller;
  final void Function(Channel) onChannelTap;

  const _RecentChatsTab({
    required this.controller,
    required this.onChannelTap,
  });

  @override
  Widget build(BuildContext context) {
    return _RecentChatsChannelList(
      controller: controller,
      onChannelTap: onChannelTap,
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
    );
  }
}

class _OnlineUsersTab extends ConsumerStatefulWidget {
  const _OnlineUsersTab();

  @override
  ConsumerState<_OnlineUsersTab> createState() => _OnlineUsersTabState();
}

class _OnlineUsersTabState extends ConsumerState<_OnlineUsersTab> {
  final Set<String> _loadingUserIds = {};

  Future<void> _openChat(UserProfileModel user) async {
    if (_loadingUserIds.contains(user.id)) return;

    setState(() => _loadingUserIds.add(user.id));

    try {
      final chatService = ChatService();
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
    final onlineUsersAsync = ref.watch(onlineUsersProvider);
    final scheme = Theme.of(context).colorScheme;

    return onlineUsersAsync.when(
      data: (users) {
        if (users.isNotEmpty) {
          ImagePrecacheService.precacheChatAvatars(context, users);
        }
        if (users.isEmpty) {
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
          onRefresh: () async =>
              ref.read(onlineUsersProvider.notifier).refreshOnlineUsers(),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.3)),
            itemBuilder: (context, index) {
              final user = users[index];
              final isLoading = _loadingUserIds.contains(user.id);

              return ListTile(
                leading: AppAvatar(
                  size: 48,
                  avatarAsset: user.avatarAsset,
                  backgroundColor: scheme.primaryContainer,
                  fallbackText: user.username?.isNotEmpty == true
                      ? user.username![0]
                      : 'U',
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
              onPressed: () =>
                  ref.read(onlineUsersProvider.notifier).refreshOnlineUsers(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
