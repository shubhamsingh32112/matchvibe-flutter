import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/styles/app_brand_styles.dart';
import '../../home/providers/availability_provider.dart';
import '../models/moments_models.dart';

class StoriesRow extends ConsumerWidget {
  const StoriesRow({
    super.key,
    required this.groups,
    this.onGroupTap,
  });

  final List<StoryGroup> groups;
  final void Function(StoryGroup group)? onGroupTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (groups.isEmpty) {
      return const SizedBox(height: 8);
    }
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final group = groups[index];
          final thumb = group.creatorAvatarUrl ??
              (group.stories.isNotEmpty
                  ? group.stories.last.media.thumbnailUrl
                  : null);
          final label = group.creatorName ?? group.creatorId.substring(0, 6);
          final availability = ref.watch(
            creatorStatusProvider(group.creatorFirebaseUid),
          );
          final isLive = availability == CreatorAvailability.online;

          return GestureDetector(
            onTap: () => onGroupTap?.call(group),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: group.unseen
                            ? AppBrandGradients.momentsStoryRingGradient
                            : null,
                        border: group.unseen
                            ? null
                            : Border.all(color: Colors.grey.shade400, width: 2),
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: thumb != null && thumb.isNotEmpty
                            ? NetworkImage(thumb)
                            : null,
                        child: thumb == null || thumb.isEmpty
                            ? Icon(Icons.person, color: Colors.grey.shade500)
                            : null,
                      ),
                    ),
                    if (isLive)
                      Positioned(
                        bottom: -2,
                        child: Container(
                          width: 36,
                          height: 14,
                          decoration: const BoxDecoration(
                            gradient: AppBrandGradients.momentsLiveBadgeGradient,
                            borderRadius: BorderRadius.all(Radius.circular(7)),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 64,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppBrandGradients.momentsTitleColor,
                      fontWeight: isLive ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (isLive)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      gradient: AppBrandGradients.momentsLiveBadgeGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
