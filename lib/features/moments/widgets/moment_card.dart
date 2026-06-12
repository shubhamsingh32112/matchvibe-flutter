import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../creator/utils/creator_home_formatters.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../models/moments_models.dart';
import '../services/moments_api_service.dart';
import 'follow_creator_button.dart';
import 'moment_viewer_chrome.dart';
import 'stream_hls_player.dart';

class LockedMomentOverlay extends StatelessWidget {
  const LockedMomentOverlay({
    super.key,
    required this.item,
    required this.onUnlocked,
    this.viewerLayout = false,
    this.bottomOverlayInset = 0,
  });

  final MomentFeedItem item;
  final ValueChanged<MomentFeedItem> onUnlocked;
  final bool viewerLayout;
  final double bottomOverlayInset;

  int get _priceCoins =>
      item.unlockPriceCoins ?? item.media.unlockPriceCoins ?? 0;

  String _unlockLabel(MomentFeedItem item) {
    if (item.vipFreeUnlockAvailable == true ||
        item.media.vipFreeUnlockAvailable == true) {
      return 'VIP Free Unlock';
    }
    if (item.discountApplied == true || item.media.discountApplied == true) {
      final original = item.originalPriceCoins ?? item.media.originalPriceCoins;
      final price = item.unlockPriceCoins ?? item.media.unlockPriceCoins ?? 0;
      if (original != null && original > price) {
        return 'VIP: $price Coins (was $original)';
      }
      return 'VIP: $price Coins';
    }
    return 'Unlock for $_priceCoins Coins';
  }

  Future<void> _purchase(BuildContext context) async {
    try {
      final api = MomentsApiService();
      final unlocked = await api.purchase(item.id);
      onUnlocked(unlocked);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (viewerLayout) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            item.media.thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black26),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: Colors.black.withValues(alpha: 0.35)),
          ),
          Positioned(
            left: 16,
            bottom: bottomOverlayInset > 0 ? bottomOverlayInset + 12 : 180,
            child: MomentViewerPremiumBadge(
              priceCoins: _priceCoins,
              onTap: () => _purchase(context),
            ),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          item.media.thumbnailUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: Colors.black26),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(color: Colors.black.withValues(alpha: 0.35)),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, color: AppPalette.onSurface, size: 40),
              const SizedBox(height: 12),
              Text(
                _unlockLabel(item),
                style: const TextStyle(
                  color: AppPalette.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _purchase(context),
                child: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
            top: 0,
            left: 0,
            right: 0,
            child: _ViewerTopCreatorHeader(
              item: item,
              timeAgo: _timeAgo,
              onCreatorTap: onCreatorTap,
              onReport: onReport,
            ),
          ),
          if (!item.locked && media.isVideo && onMuteToggle != null)
            Positioned(
              right: 16,
              bottom: bottomOverlayInset > 0 ? bottomOverlayInset + 24 : 200,
              child: _MuteToggleButton(
                isMuted: isVideoMuted,
                onTap: onMuteToggle!,
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

class _ViewerTopCreatorHeader extends StatelessWidget {
  const _ViewerTopCreatorHeader({
    required this.item,
    required this.timeAgo,
    this.onCreatorTap,
    this.onReport,
  });

  final MomentFeedItem item;
  final String timeAgo;
  final VoidCallback? onCreatorTap;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.65),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onCreatorTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white24,
                  backgroundImage: item.creatorAvatarUrl != null &&
                          item.creatorAvatarUrl!.isNotEmpty
                      ? NetworkImage(item.creatorAvatarUrl!)
                      : null,
                  child: item.creatorAvatarUrl == null ||
                          item.creatorAvatarUrl!.isEmpty
                      ? const Icon(Icons.person, color: Colors.white, size: 20)
                      : null,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.creatorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified,
                          size: 16,
                          color: AppBrandGradients.creatorProfileInactiveTabColor,
                        ),
                      ],
                    ),
                    if (timeAgo.isNotEmpty)
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white),
            onPressed: onReport,
          ),
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
