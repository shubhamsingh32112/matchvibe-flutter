import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/app_nav_destinations.dart';
import '../../../app/widgets/main_layout.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../../home/widgets/creator_profile_screen.dart';
import '../providers/moments_providers.dart';
import '../widgets/reels_feed.dart';
import '../widgets/stories_row.dart';
import 'story_viewer_screen.dart';

class MomentsScreen extends ConsumerWidget {
  const MomentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(momentsFeedTabProvider);
    final storiesAsync = ref.watch(storiesBarProvider);

    return MainLayout(
      selectedIndex: AppNavDestinations.momentsIndex,
      appBar: buildBrandAppBar(context, title: 'Moments'),
      child: Column(
        children: [
          storiesAsync.when(
            data: (groups) => StoriesRow(
              groups: groups,
              onGroupTap: (group) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StoryViewerScreen(group: group),
                  ),
                );
              },
            ),
            loading: () => const SizedBox(
              height: 96,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => const SizedBox(height: 8),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                BrandFeedTabChip(
                  label: 'For You',
                  selected: tab == MomentsFeedTab.forYou,
                  onTap: () => ref.read(momentsFeedTabProvider.notifier).state =
                      MomentsFeedTab.forYou,
                ),
                const SizedBox(width: 8),
                BrandFeedTabChip(
                  label: 'Following',
                  selected: tab == MomentsFeedTab.following,
                  onTap: () => ref.read(momentsFeedTabProvider.notifier).state =
                      MomentsFeedTab.following,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: tab == MomentsFeedTab.forYou
                ? const _ForYouFeedBody()
                : const _FollowingFeedBody(),
          ),
        ],
      ),
    );
  }
}

class _ForYouFeedBody extends ConsumerWidget {
  const _ForYouFeedBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(forYouFeedProvider);
    return feedAsync.when(
      data: (items) => ReelsFeed(
        items: items,
        onLoadMore: () => ref.read(forYouFeedProvider.notifier).loadMore(),
        onItemUpdated: (index, item) =>
            ref.read(forYouFeedProvider.notifier).updateItem(index, item),
        onCreatorTap: (id) => openCreatorProfile(context, ref, id),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load feed: $e')),
    );
  }
}

class _FollowingFeedBody extends ConsumerWidget {
  const _FollowingFeedBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(followingFeedProvider);
    return feedAsync.when(
      data: (items) => ReelsFeed(
        items: items,
        onLoadMore: () => ref.read(followingFeedProvider.notifier).loadMore(),
        onItemUpdated: (index, item) =>
            ref.read(followingFeedProvider.notifier).updateItem(index, item),
        onCreatorTap: (id) => openCreatorProfile(context, ref, id),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load feed: $e')),
    );
  }
}
