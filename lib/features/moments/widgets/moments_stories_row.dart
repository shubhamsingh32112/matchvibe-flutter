import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/styles/app_brand_styles.dart';
import '../../creator/providers/creator_dashboard_provider.dart';
import '../../home/providers/availability_provider.dart';
import '../models/moments_models.dart';
import '../providers/moments_providers.dart';
import '../screens/story_viewer_screen.dart';
import 'stories_row.dart';

class MomentsStoriesRow extends ConsumerWidget {
  const MomentsStoriesRow({
    super.key,
    required this.groups,
    required this.onGroupTap,
    this.isCreator = false,
    this.onAddStory,
  });

  final List<StoryGroup> groups;
  final void Function(StoryGroup group) onGroupTap;
  final bool isCreator;
  final VoidCallback? onAddStory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isCreator || onAddStory == null) {
      return StoriesRow(groups: groups, onGroupTap: onGroupTap);
    }

    final myCreatorId = ref.watch(
      creatorDashboardProvider.select((a) => a.valueOrNull?.creatorProfile.id),
    );
    final myStoriesAsync = ref.watch(myStoriesProvider);
    final otherGroups = myCreatorId == null
        ? groups
        : groups.where((g) => g.creatorId != myCreatorId).toList();

    return SizedBox(
      height: 104,
      child: myStoriesAsync.when(
        data: (myStories) => _buildList(
          context,
          ref,
          feedGroups: groups,
          myStories: myStories,
          otherGroups: otherGroups,
          myCreatorId: myCreatorId,
        ),
        loading: () => _buildList(
          context,
          ref,
          feedGroups: groups,
          myStories: const [],
          otherGroups: otherGroups,
          myCreatorId: myCreatorId,
        ),
        error: (_, __) => StoriesRow(groups: groups, onGroupTap: onGroupTap),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref, {
    required List<StoryGroup> feedGroups,
    required List<StoryPresentation> myStories,
    required List<StoryGroup> otherGroups,
    required String? myCreatorId,
  }) {
    void openViewer({
      required int initialGroupIndex,
      int initialStoryIndex = 0,
    }) {
      final viewerGroups = buildStoryViewerGroups(
        feedGroups: feedGroups,
        myStories: myStories.isNotEmpty ? myStories : null,
        myCreatorId: myCreatorId,
      );
      if (viewerGroups.isEmpty || initialGroupIndex >= viewerGroups.length) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StoryViewerScreen(
            groups: viewerGroups,
            initialGroupIndex: initialGroupIndex,
            initialStoryIndex: initialStoryIndex,
          ),
        ),
      );
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: 1 + otherGroups.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _YourStorySlot(
            myStories: myStories,
            onAddStory: onAddStory!,
            onViewStories: myStories.isEmpty
                ? null
                : () => openViewer(initialGroupIndex: 0),
          );
        }
        final group = otherGroups[index - 1];
        return _FeedStoryCircle(
          group: group,
          onTap: () {
            final viewerGroups = buildStoryViewerGroups(
              feedGroups: feedGroups,
              myStories: myStories.isNotEmpty ? myStories : null,
              myCreatorId: myCreatorId,
            );
            final groupIndex = storyViewerGroupIndex(viewerGroups, group);
            if (groupIndex < 0) return;
            openViewer(initialGroupIndex: groupIndex);
          },
        );
      },
    );
  }
}

class _YourStorySlot extends StatelessWidget {
  const _YourStorySlot({
    required this.myStories,
    required this.onAddStory,
    this.onViewStories,
  });

  final List<StoryPresentation> myStories;
  final VoidCallback onAddStory;
  final VoidCallback? onViewStories;

  @override
  Widget build(BuildContext context) {
    final hasStories = myStories.isNotEmpty;
    final latest = hasStories ? myStories.last : null;
    final thumbUrl = latest?.media.thumbnailUrl;

    return GestureDetector(
      onTap: hasStories ? onViewStories : onAddStory,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: hasStories
                      ? AppBrandGradients.momentsStoryRingGradient
                      : null,
                  border: hasStories
                      ? null
                      : Border.all(
                          color: AppBrandGradients.momentsTabActiveColor,
                          width: 2,
                        ),
                ),
                child: hasStories
                    ? CircleAvatar(
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: thumbUrl != null && thumbUrl.isNotEmpty
                            ? NetworkImage(thumbUrl)
                            : null,
                        child: thumbUrl == null || thumbUrl.isEmpty
                            ? Icon(Icons.person, color: Colors.grey.shade500)
                            : null,
                      )
                    : const Icon(
                        Icons.add,
                        color: AppBrandGradients.momentsTabActiveColor,
                        size: 28,
                      ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: GestureDetector(
                  onTap: onAddStory,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppBrandGradients.momentsViewerActionGradient,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(
              'Your Story',
              style: TextStyle(
                fontSize: 11,
                color: AppBrandGradients.momentsTitleColor,
                fontWeight: hasStories ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedStoryCircle extends ConsumerWidget {
  const _FeedStoryCircle({
    required this.group,
    required this.onTap,
  });

  final StoryGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      onTap: onTap,
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
  }
}
