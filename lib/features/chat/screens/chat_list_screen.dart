import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../app/widgets/main_layout.dart';
import '../../../shared/models/profile_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/home_provider.dart';
import '../../user/providers/user_availability_provider.dart';
import '../../../core/services/availability_socket_service.dart';
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation after a video call',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No conversations yet',
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Users will appear here after they message you',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
  bool _requestedInitialAvailability = false;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chat: $e'),
            backgroundColor: Colors.red,
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
    final userAvailabilityMap = ref.watch(userAvailabilityProvider);
    final scheme = Theme.of(context).colorScheme;

    return usersAsync.when(
      data: (users) {
        // On first successful load, request a real-time availability batch for all users.
        if (!_requestedInitialAvailability && users.isNotEmpty) {
          _requestedInitialAvailability = true;
          final socketService = ref.read(availabilitySocketServiceProvider);
          final firebaseUids = users
              .where((u) => u.firebaseUid != null)
              .map((u) => u.firebaseUid!)
              .toList();
          if (firebaseUids.isNotEmpty) {
            socketService.requestUserAvailability(firebaseUids);
          }
        }

        // 🔥 NEW: Filter to show only online users
        // Use real-time availability from Socket.IO (userAvailabilityProvider)
        // Fallback to API availability if socket data not available
        final onlineUsers = users.where((user) {
          if (user.firebaseUid == null) return false;
          
          // Check real-time availability first (from Socket.IO)
          final realTimeStatus = userAvailabilityMap[user.firebaseUid];
          if (realTimeStatus != null) {
            return realTimeStatus == UserAvailability.online;
          }
          
          // Fallback to API availability
          return user.availability == 'online';
        }).toList();

        if (onlineUsers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No online users',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Users will appear here when they come online',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(usersProvider),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: onlineUsers.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.3)),
            itemBuilder: (context, index) {
              final user = onlineUsers[index];
              final isLoading = _loadingUserIds.contains(user.id);
              
              // Get real-time availability status
              final isOnline = user.firebaseUid != null &&
                  (userAvailabilityMap[user.firebaseUid] ?? 
                   (user.availability == 'online' 
                       ? UserAvailability.online 
                       : UserAvailability.offline)) == UserAvailability.online;

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
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline 
                            ? Colors.green 
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'Online' : 'Offline',
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
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load users',
              style: TextStyle(fontSize: 16, color: scheme.onSurface),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.invalidate(usersProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
