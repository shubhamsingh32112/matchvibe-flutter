import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/moments_models.dart';
import '../services/moments_api_service.dart';
import 'follow_creator_button.dart';
import 'stream_hls_player.dart';

class LockedMomentOverlay extends StatelessWidget {
  const LockedMomentOverlay({
    super.key,
    required this.item,
    required this.onUnlocked,
  });

  final MomentFeedItem item;
  final ValueChanged<MomentFeedItem> onUnlocked;

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
    return 'Unlock for ${item.unlockPriceCoins ?? item.media.unlockPriceCoins ?? 0} Coins';
  }

  @override
  Widget build(BuildContext context) {
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
}

class MomentCard extends StatelessWidget {
  const MomentCard({
    super.key,
    required this.item,
    required this.onItemUpdated,
    this.onCreatorTap,
    this.playbackContext = 'reels',
    this.playerInitDelay = Duration.zero,
  });

  final MomentFeedItem item;
  final ValueChanged<MomentFeedItem> onItemUpdated;
  final VoidCallback? onCreatorTap;
  final String playbackContext;
  final Duration playerInitDelay;

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
          LockedMomentOverlay(item: item, onUnlocked: onItemUpdated)
        else if (media.isVideo && media.playbackUrl != null)
          StreamHlsPlayer(
            key: ValueKey('${item.id}-${media.playbackUrl}'),
            momentId: item.id,
            playbackUrl: media.playbackUrl!,
            expiresAtMs: media.expiresAtMs,
            playbackContext: playbackContext,
            initDelay: playerInitDelay,
          )
        else if (media.playbackUrl != null)
          Image.network(media.playbackUrl!, fit: BoxFit.cover)
        else
          Image.network(media.thumbnailUrl, fit: BoxFit.cover),
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
                      child: Text(
                        item.creatorName,
                        style: const TextStyle(
                          color: AppPalette.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
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
