import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/image_precache_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../app/widgets/main_layout.dart';
import '../../../shared/widgets/skeleton_list.dart';
import '../../../shared/widgets/gem_icon.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/services/chat_service.dart';
import '../../home/providers/availability_provider.dart';
import '../../video/controllers/call_connection_controller.dart';
import '../../../shared/providers/coin_purchase_popup_provider.dart';
import '../models/call_history_model.dart';
import '../providers/recent_provider.dart';

class RecentScreen extends ConsumerStatefulWidget {
  const RecentScreen({super.key});

  @override
  ConsumerState<RecentScreen> createState() => _RecentScreenState();
}

class _RecentScreenState extends ConsumerState<RecentScreen> {
  Future<void> _refresh() async {
    ref.invalidate(recentCallsProvider);
    await ref.read(recentCallsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final recentCallsAsync = ref.watch(recentCallsProvider);

    return MainLayout(
      selectedIndex: 1,
      child: recentCallsAsync.when(
        loading: () => const SkeletonList(itemCount: 8),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text('Failed to load recent calls',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  UserMessageMapper.userMessageFor(
                    err,
                    fallback: 'Couldn\'t load recent calls. Please try again.',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (calls) {
          if (calls.isNotEmpty) {
            ImagePrecacheService.precacheRecentCalls(context, calls);
          }
          if (calls.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 64, color: AppPalette.emptyIcon),
                  const SizedBox(height: 16),
                  Text(
                    'No recent calls',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppPalette.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your call history will appear here',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppPalette.subtitle,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: calls.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 76, endIndent: 16),
              itemBuilder: (context, index) {
                final call = calls[index];
                return _CallHistoryTile(call: call);
              },
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Single call history tile
// ═══════════════════════════════════════════════════════════════════════════

class _CallHistoryTile extends ConsumerWidget {
  final CallHistoryModel call;
  const _CallHistoryTile({required this.call});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isOutgoing = call.isOutgoing;
    final timeAgo = _formatTimeAgo(call.createdAt);

    // Only show call button for regular users (outgoing calls to creators)
    final authState = ref.watch(authProvider);
    final isRegularUser = authState.user?.role == 'user';
    final showCallButton = isRegularUser && isOutgoing;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: AppAvatar(
        size: 48,
        avatarAsset: call.otherAvatarAsset,
        imageUrlOverride:
            call.otherAvatarAsset == null ? call.otherAvatar : null,
        backgroundColor: scheme.primaryContainer,
        fallbackText: call.otherName.isNotEmpty ? call.otherName[0] : 'U',
      ),
      title: Text(
        call.otherName,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          // Direction icon
          Icon(
            isOutgoing ? Icons.call_made : Icons.call_received,
            size: 14,
            color: isOutgoing ? AppPalette.success : scheme.primary,
          ),
          const SizedBox(width: 4),
          // Duration
          Text(
            call.formattedDuration,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(width: 8),
          // Coin info
          const GemIcon(size: 12),
          const SizedBox(width: 2),
          Text(
            isOutgoing ? '-${call.coinsDeducted}' : '+${call.coinsEarned}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isOutgoing ? scheme.error : AppPalette.success,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(width: 8),
          // Time ago
          Expanded(
            child: Text(
              timeAgo,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChatButton(otherFirebaseUid: call.otherFirebaseUid),
          if (showCallButton)
            _CallButton(
              otherFirebaseUid: call.otherFirebaseUid,
              otherMongoId: call.otherMongoIdForCall,
              otherAvatar: call.otherAvatar,
              otherName: call.otherName,
            ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return DateFormat('MMM d').format(date);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Chat button — creates/opens channel with the other party
// ═══════════════════════════════════════════════════════════════════════════

class _ChatButton extends StatefulWidget {
  final String otherFirebaseUid;
  const _ChatButton({required this.otherFirebaseUid});

  @override
  State<_ChatButton> createState() => _ChatButtonState();
}

class _ChatButtonState extends State<_ChatButton> {
  bool _loading = false;

  Future<void> _openChat() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final chatService = ChatService();
      final result =
          await chatService.createOrGetChannel(widget.otherFirebaseUid);
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _openChat,
      icon: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.chat_bubble_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
      tooltip: 'Chat',
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Call button — initiates a video call with the creator
// ═══════════════════════════════════════════════════════════════════════════

class _CallButton extends ConsumerStatefulWidget {
  final String otherFirebaseUid;
  final String otherMongoId;
  final String? otherAvatar;
  final String otherName;

  const _CallButton({
    required this.otherFirebaseUid,
    required this.otherMongoId,
    this.otherAvatar,
    required this.otherName,
  });

  @override
  ConsumerState<_CallButton> createState() => _CallButtonState();
}

class _CallButtonState extends ConsumerState<_CallButton> {
  bool _loading = false;

  Future<void> _initiateCall() async {
    if (_loading) return;

    // Check coin balance
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user != null && user.spendableCallCoins < 10) {
      if (mounted) {
        ref.read(coinPurchasePopupProvider.notifier).state = CoinPopupIntent(
          reason: 'preflight_low_coins_recent',
          dedupeKey: 'low-coins-recent-${widget.otherMongoId}',
          remoteDisplayName: widget.otherName,
          remotePhotoUrl: widget.otherAvatar,
          remoteFirebaseUid: widget.otherFirebaseUid,
        );
      }
      return;
    }

    setState(() => _loading = true);

    try {
      await ref
          .read(callConnectionControllerProvider.notifier)
          .startUserCall(
            creatorFirebaseUid: widget.otherFirebaseUid,
            creatorMongoId: widget.otherMongoId,
            creatorImageUrl: widget.otherAvatar,
            creatorName: widget.otherName,
          );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Check if creator is online
    final availabilityMap = ref.watch(creatorAvailabilityProvider);
    final isOnline =
        (availabilityMap[widget.otherFirebaseUid] ?? CreatorAvailability.busy) ==
            CreatorAvailability.online;

    return IconButton(
      onPressed: isOnline ? _initiateCall : null,
      icon: _loading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            )
          : Icon(
              Icons.videocam,
              color: isOnline
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.3),
            ),
      tooltip: isOnline ? 'Video Call' : 'Offline',
    );
  }
}
