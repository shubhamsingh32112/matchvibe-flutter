import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../creator/utils/creator_home_formatters.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../models/moments_models.dart';
import '../utils/moment_caption_utils.dart';
import 'follow_creator_button.dart';
import 'locked_moment_overlay.dart';
import 'moment_action_rail.dart';
import 'stream_hls_player.dart';

class MomentCard extends StatelessWidget {
  const MomentCard({
    super.key,
    required this.item,
    required this.onItemUpdated,
    this.onCreatorTap,
    this.onReport,
    this.playbackContext = 'reels',
    this.playerInitDelay = Duration.zero,
    this.viewerLayout = false,
    this.isVideoMuted = true,
    this.onMuteToggle,
    this.bottomOverlayInset = 0,
    this.showEngagementRail = false,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onFollowChanged,
    this.showFollowOnRail = true,
    this.engagementEnabled = true,
    this.isLikeBusy = false,
    this.isShareBusy = false,
  });

  final MomentFeedItem item;
  final ValueChanged<MomentFeedItem> onItemUpdated;
  final VoidCallback? onCreatorTap;
  final VoidCallback? onReport;
  final String playbackContext;
  final Duration playerInitDelay;
  final bool viewerLayout;
  final bool isVideoMuted;
  final VoidCallback? onMuteToggle;
  final double bottomOverlayInset;
  final bool showEngagementRail;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final void Function(bool isFollowing, int followerCount)? onFollowChanged;
  final bool showFollowOnRail;
  final bool engagementEnabled;
  final bool isLikeBusy;
  final bool isShareBusy;

  String get _timeAgo {
    final parsed = DateTime.tryParse(item.createdAt);
    return formatRelativeStoryTime(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final media = item.media;
    if (!media.isReady) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(media.thumbnailUrl, fit: BoxFit.cover),
          Container(color: Colors.black54),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppPalette.onSurface),
                SizedBox(height: 12),
                Text(
                  'Processing…',
                  style: TextStyle(color: AppPalette.onSurface),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (item.locked)
          LockedMomentOverlay(
            item: item,
            onUnlocked: onItemUpdated,
            viewerLayout: viewerLayout,
            bottomOverlayInset: bottomOverlayInset,
          )
        else if (media.isVideo && media.playbackUrl != null)
          StreamHlsPlayer(
            key: ValueKey('${item.id}-${media.playbackUrl}'),
            momentId: item.id,
            playbackUrl: media.playbackUrl!,
            expiresAtMs: media.expiresAtMs,
            playbackContext: playbackContext,
            initDelay: playerInitDelay,
            muted: isVideoMuted,
          )
        else if (media.playbackUrl != null)
          Image.network(media.playbackUrl!, fit: BoxFit.cover)
        else
          Image.network(media.thumbnailUrl, fit: BoxFit.cover),
        if (viewerLayout) ...[
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!item.locked && media.isVideo && onMuteToggle != null)
                  _MuteToggleButton(
                    isMuted: isVideoMuted,
                    onTap: onMuteToggle!,
                  ),
                if (onReport != null)
                  IconButton(
                    icon: const Icon(Icons.more_horiz, color: Colors.white),
                    onPressed: onReport,
                  ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: showEngagementRail ? 88 : 16,
            bottom: bottomOverlayInset > 0 ? bottomOverlayInset + 8 : 24,
            child: _ViewerBottomInfo(
              item: item,
              timeAgo: _timeAgo,
              onCreatorTap: onCreatorTap,
            ),
          ),
          if (showEngagementRail &&
              onLike != null &&
              onComment != null &&
              onShare != null)
            Positioned(
              right: 12,
              bottom: bottomOverlayInset > 0 ? bottomOverlayInset + 72 : 160,
              child: MomentActionRail(
                item: item,
                onLike: onLike!,
                onComment: onComment!,
                onShare: onShare!,
                onFollowChanged: onFollowChanged,
                showFollow: showFollowOnRail,
                engagementEnabled: engagementEnabled,
                isLikeBusy: isLikeBusy,
                isShareBusy: isShareBusy,
              ),
            ),
        ] else
          Positioned(
            left: 16,
            bottom: 100,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onCreatorTap,
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.white24,
                              backgroundImage:
                                  item.creatorAvatarUrl != null &&
                                      item.creatorAvatarUrl!.isNotEmpty
                                  ? NetworkImage(item.creatorAvatarUrl!)
                                  : null,
                              child:
                                  item.creatorAvatarUrl == null ||
                                      item.creatorAvatarUrl!.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      size: 18,
                                      color: AppPalette.onSurface,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.creatorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppPalette.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!item.isFollowing)
                      FollowCreatorButton(
                        creatorId: item.creatorId,
                        initiallyFollowing: item.isFollowing,
                        compact: true,
                        onFollowChanged: (_, __) {
                          onItemUpdated(
                            item.copyWith(isFollowing: true),
                          );
                        },
                      ),
                  ],
                ),
                if (item.caption != null && item.caption!.isNotEmpty)
                  Text(
                    item.caption!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppPalette.subtitle),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ViewerBottomInfo extends StatelessWidget {
  const _ViewerBottomInfo({
    required this.item,
    required this.timeAgo,
    this.onCreatorTap,
  });

  final MomentFeedItem item;
  final String timeAgo;
  final VoidCallback? onCreatorTap;

  @override
  Widget build(BuildContext context) {
    final hashtags = extractHashtags(item.caption);
    final captionText = captionWithoutHashtags(item.caption);

    return GestureDetector(
      onTap: onCreatorTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white24,
                backgroundImage: item.creatorAvatarUrl != null &&
                        item.creatorAvatarUrl!.isNotEmpty
                    ? NetworkImage(item.creatorAvatarUrl!)
                    : null,
                child: item.creatorAvatarUrl == null ||
                        item.creatorAvatarUrl!.isEmpty
                    ? const Icon(Icons.person, color: Colors.white, size: 16)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.creatorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified,
                          size: 14,
                          color: AppBrandGradients.creatorProfileInactiveTabColor,
                        ),
                      ],
                    ),
                    if (timeAgo.isNotEmpty)
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (captionText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              captionText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ],
          if (hashtags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: hashtags
                  .map(
                    (tag) => Text(
                      tag,
                      style: TextStyle(
                        color: AppBrandGradients.momentsTabActiveColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _MuteToggleButton extends StatelessWidget {
  const _MuteToggleButton({
    required this.isMuted,
    required this.onTap,
  });

  final bool isMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            isMuted ? Icons.volume_off : Icons.volume_up,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
