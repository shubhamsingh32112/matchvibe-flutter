import 'package:flutter/material.dart';

import '../models/moments_models.dart';

class StoriesRow extends StatelessWidget {
  const StoriesRow({
    super.key,
    required this.groups,
    this.onGroupTap,
  });

  final List<StoryGroup> groups;
  final void Function(StoryGroup group)? onGroupTap;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const SizedBox(height: 8);
    }
    return SizedBox(
      height: 96,
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
          return GestureDetector(
            onTap: () => onGroupTap?.call(group),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: group.unseen
                        ? const LinearGradient(
                            colors: [
                              Color(0xFFFD1D1D),
                              Color(0xFF833AB4),
                              Color(0xFFFCAF45),
                            ],
                          )
                        : null,
                    border: group.unseen
                        ? null
                        : Border.all(color: Colors.grey.shade600, width: 2),
                  ),
                  child: CircleAvatar(
                    backgroundColor: Colors.grey.shade900,
                    backgroundImage:
                        thumb != null && thumb.isNotEmpty ? NetworkImage(thumb) : null,
                    child: thumb == null || thumb.isEmpty
                        ? const Icon(Icons.person, color: Colors.white54)
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 64,
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
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
