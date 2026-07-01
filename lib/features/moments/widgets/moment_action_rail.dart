import 'package:flutter/material.dart';

import '../../../core/utils/compact_count_formatter.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../models/moments_models.dart';
import 'follow_creator_button.dart';

class MomentActionRail extends StatelessWidget {
  const MomentActionRail({
    super.key,
    required this.item,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    this.onFollowChanged,
    this.showFollow = true,
    this.engagementEnabled = true,
    this.isLikeBusy = false,
    this.isShareBusy = false,
  });

  final MomentFeedItem item;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final void Function(bool isFollowing, int followerCount)? onFollowChanged;
  final bool showFollow;
  final bool engagementEnabled;
  final bool isLikeBusy;
  final bool isShareBusy;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showFollow) ...[
          FollowCreatorButton(
            creatorId: item.creatorId,
            initiallyFollowing: item.isFollowing,
            style: CreatorFollowButtonStyle.reelsAvatar,
            creatorAvatarUrl: item.creatorAvatarUrl,
            creatorName: item.creatorName,
            onFollowChanged: onFollowChanged,
          ),
          const SizedBox(height: 18),
        ],
        _ActionButton(
          icon: item.isLiked ? Icons.favorite : Icons.favorite_border,
          iconColor: item.isLiked
              ? AppBrandGradients.creatorProfileAccentPink
              : Colors.white,
          label: formatCompactCount(item.likesCount),
          onTap: engagementEnabled && !isLikeBusy ? onLike : null,
          isLoading: isLikeBusy,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          label: formatCompactCount(item.commentsCount),
          onTap: engagementEnabled ? onComment : null,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.send_outlined,
          label: 'Share',
          onTap: !isShareBusy ? onShare : null,
          isLoading: isShareBusy,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.iconColor = Colors.white,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color iconColor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            Icon(icon, color: iconColor, size: 30),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
