import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../moments/models/moments_models.dart';
import '../../../moments/providers/moments_providers.dart';
import '../../../moments/screens/story_viewer_screen.dart';
import '../../../moments/utils/moment_owner_actions.dart';
import '../../../moments/widgets/moments_upload_flow.dart';
import '../../../../shared/styles/app_brand_styles.dart';
import '../../providers/creator_dashboard_provider.dart';
import '../../theme/creator_home_tokens.dart';
import '../../utils/creator_home_formatters.dart';

class CreatorHomeStoriesSection extends ConsumerWidget {
  const CreatorHomeStoriesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myStoriesAsync = ref.watch(myStoriesProvider);
    final feedAsync = ref.watch(storiesBarProvider);
    final myCreatorId = ref.watch(
      creatorDashboardProvider.select(
        (a) => a.valueOrNull?.creatorProfile.id,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: CreatorHomeTokens.sectionSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Stories',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: CreatorHomeTokens.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/account/my-moments'),
                child: const Text(
                  'View all',
                  style: TextStyle(color: CreatorHomeTokens.primaryPurple),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 108,
            child: myStoriesAsync.when(
              data: (myStories) {
                final feedGroups = feedAsync.valueOrNull ?? [];
                final otherGroups = feedGroups
                    .where((g) => g.creatorId != myCreatorId)
                    .toList();

                void openStoryViewer({
                  int initialStoryIndex = 0,
                  StoryGroup? tappedOtherGroup,
                }) {
                  final viewerGroups = buildStoryViewerGroups(
                    feedGroups: feedGroups,
                    myStories: myStories.isNotEmpty ? myStories : null,
                    myCreatorId: myCreatorId,
                  );
                  if (viewerGroups.isEmpty) return;

                  final groupIndex = tappedOtherGroup != null
                      ? storyViewerGroupIndex(viewerGroups, tappedOtherGroup)
                      : 0;
                  if (groupIndex < 0) return;

                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StoryViewerScreen(
                        groups: viewerGroups,
                        initialGroupIndex: groupIndex,
                        initialStoryIndex: tappedOtherGroup == null
                            ? initialStoryIndex
                            : 0,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 1 + myStories.length + otherGroups.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _AddStoryButton(
                        onTap: () => startStoryUploadFlow(context, ref),
                      );
                    }
                    if (index <= myStories.length) {
                      final story = myStories[index - 1];
                      return _StoryCircle(
                        label: story.caption?.trim().isNotEmpty == true
                            ? story.caption!
                            : 'My story',
                        thumbUrl: story.media.thumbnailUrl,
                        subtitle: formatRelativeStoryTime(
                          DateTime.tryParse(story.createdAt)?.toLocal(),
                        ),
                        hasRing: true,
                        onTap: () => openStoryViewer(
                          initialStoryIndex: index - 1,
                        ),
                        onLongPress: () async {
                          await deleteStoryWithRefresh(ref, context, story.id);
                        },
                      );
                    }
                    final group = otherGroups[index - 1 - myStories.length];
                    final thumb = group.creatorAvatarUrl ??
                        (group.stories.isNotEmpty
                            ? group.stories.last.media.thumbnailUrl
                            : null);
                    return _StoryCircle(
                      label: group.creatorName ?? 'Creator',
                      thumbUrl: thumb,
                      subtitle: group.stories.isNotEmpty
                          ? formatRelativeStoryTime(
                              DateTime.tryParse(
                                group.stories.last.createdAt,
                              )?.toLocal(),
                            )
                          : '',
                      hasRing: group.unseen,
                      onTap: () => openStoryViewer(
                        tappedOtherGroup: group,
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, __) => ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _AddStoryButton(
                    onTap: () => startStoryUploadFlow(context, ref),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddStoryButton extends StatelessWidget {
  const _AddStoryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: CreatorHomeTokens.pinkAccent,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: const Icon(
              Icons.add,
              color: CreatorHomeTokens.pinkAccent,
              size: 28,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add Story',
            style: TextStyle(fontSize: 11, color: CreatorHomeTokens.labelGrey),
          ),
        ],
      ),
    );
  }
}

class _StoryCircle extends StatelessWidget {
  const _StoryCircle({
    required this.label,
    required this.thumbUrl,
    required this.subtitle,
    required this.hasRing,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final String? thumbUrl;
  final String subtitle;
  final bool hasRing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: hasRing
                  ? AppBrandGradients.momentsStoryRingGradient
                  : null,
              border: hasRing
                  ? null
                  : Border.all(color: Colors.grey.shade400, width: 2),
            ),
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade200,
              backgroundImage: thumbUrl != null && thumbUrl!.isNotEmpty
                  ? NetworkImage(thumbUrl!)
                  : null,
              child: thumbUrl == null || thumbUrl!.isEmpty
                  ? Icon(Icons.person, color: Colors.grey.shade500)
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 72,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: CreatorHomeTokens.textPrimary,
              ),
            ),
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: CreatorHomeTokens.labelGrey,
              ),
            ),
        ],
      ),
    );
  }
}
