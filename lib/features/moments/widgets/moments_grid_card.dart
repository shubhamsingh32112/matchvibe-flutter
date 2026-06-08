import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../shared/styles/app_brand_styles.dart';
import '../models/moments_models.dart';
import '../utils/moment_caption_utils.dart';

class MomentsGridCard extends StatelessWidget {
  const MomentsGridCard({
    super.key,
    required this.item,
    this.onTap,
    this.onViewCreator,
    this.onReport,
  });

  final MomentFeedItem item;
  final VoidCallback? onTap;
  final VoidCallback? onViewCreator;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = captionWithoutHashtags(item.caption);
    final hashtag = extractFirstHashtag(item.caption);
    final isVideo = item.media.isVideo;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppBrandGradients.momentsCardRadius),
          boxShadow: AppBrandGradients.momentsCardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppBrandGradients.momentsCardRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                item.media.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: scheme.surfaceContainerHigh,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
              if (item.locked) ...[
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Image.network(
                    item.media.thumbnailUrl,
                    fit: BoxFit.cover,
                  ),
                ),
                Container(color: Colors.black.withValues(alpha: 0.35)),
                const Center(
                  child: Icon(Icons.lock_outline, color: Colors.white, size: 28),
                ),
              ],
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppBrandGradients.userCardOverlay(scheme),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: _MediaTypeChip(isVideo: isVideo),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  onPressed: () => _showActionSheet(context),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 40,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (caption.isNotEmpty)
                      Text(
                        caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                    if (hashtag != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        hashtag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: Colors.white24,
                      backgroundImage: item.creatorAvatarUrl != null &&
                              item.creatorAvatarUrl!.isNotEmpty
                          ? NetworkImage(item.creatorAvatarUrl!)
                          : null,
                      child: item.creatorAvatarUrl == null ||
                              item.creatorAvatarUrl!.isEmpty
                          ? const Icon(Icons.person, size: 12, color: Colors.white70)
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.creatorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.verified,
                            size: 13,
                            color: AppBrandGradients.momentsTabActiveColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('View creator profile'),
              onTap: () {
                Navigator.pop(ctx);
                onViewCreator?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(ctx);
                onReport?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaTypeChip extends StatelessWidget {
  const _MediaTypeChip({required this.isVideo});

  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        isVideo ? Icons.movie_outlined : Icons.photo_outlined,
        color: Colors.white,
        size: 14,
      ),
    );
  }
}
