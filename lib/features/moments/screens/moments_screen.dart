import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/app_nav_index.dart';
import '../../../app/widgets/main_layout.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../auth/providers/auth_provider.dart';
import '../../creator/providers/creator_dashboard_provider.dart';
import '../../home/widgets/creator_profile_screen.dart';
import '../models/moments_models.dart';
import '../providers/moments_providers.dart';
import '../widgets/moments_upload_flow.dart';
import '../widgets/moments_add_center_button.dart';
import '../widgets/moments_feed_tab_bar.dart';
import '../widgets/moments_grid_feed.dart';
import '../widgets/moments_stories_row.dart';
import '../widgets/moments_header.dart';
import 'story_viewer_screen.dart';

class MomentsScreen extends ConsumerWidget {
  const MomentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(momentsFeedTabProvider);
    final filter = ref.watch(momentsMediaFilterProvider);
    final storiesAsync = ref.watch(storiesBarProvider);
    final canUploadMoments = ref.watch(
      authProvider.select(
        (s) => s.user?.role == 'creator' || s.user?.role == 'admin',
      ),
    );
    final myCreatorId = ref.watch(
      creatorDashboardProvider.select((a) => a.valueOrNull?.creatorProfile.id),
    );
    void openPostReelSheet() => startMomentUploadFlow(context, ref);
    void openStoryUpload() => startStoryUploadFlow(context, ref);

    return MainLayout(
      selectedIndex: appNavSelectedIndex(ref, '/moments'),
      accountMenuStyle: true,
      appBar: MomentsHeader.appBar(context, ref),
      child: Stack(
        children: [
          ColoredBox(
            color: AppBrandGradients.momentsPageBackground,
            child: Column(
              children: [
                storiesAsync.when(
                  data: (groups) => MomentsStoriesRow(
                    groups: groups,
                    isCreator: canUploadMoments,
                    onAddStory: canUploadMoments ? openStoryUpload : null,
                    onGroupTap: (group) {
                      final myStories = canUploadMoments
                          ? ref.read(myStoriesProvider).valueOrNull
                          : null;
                      final viewerGroups = buildStoryViewerGroups(
                        feedGroups: groups,
                        myStories: myStories,
                        myCreatorId: myCreatorId,
                      );
                      final groupIndex = storyViewerGroupIndex(
                        viewerGroups,
                        group,
                      );
                      if (groupIndex < 0) return;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => StoryViewerScreen(
                            groups: viewerGroups,
                            initialGroupIndex: groupIndex,
                          ),
                        ),
                      );
                    },
                  ),
                  loading: () => const SizedBox(
                    height: 104,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (_, __) => const SizedBox(height: 8),
                ),
                const MomentsFeedTabBar(),
                Expanded(
                  child: switch (tab) {
                    MomentsFeedTab.popular => _PopularFeedBody(
                        filter: filter,
                        showCreatorFab: canUploadMoments,
                        onAddMoment: canUploadMoments ? openPostReelSheet : null,
                      ),
                    MomentsFeedTab.following => _FollowingFeedBody(
                        filter: filter,
                        showCreatorFab: canUploadMoments,
                        onAddMoment: canUploadMoments ? openPostReelSheet : null,
                      ),
                  },
                ),
              ],
            ),
          ),
          if (canUploadMoments)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MomentsPostReelFab(onTap: openPostReelSheet),
              ),
            ),
        ],
      ),
    );
  }
}

class _FollowingFeedBody extends ConsumerWidget {
  const _FollowingFeedBody({
    required this.filter,
    this.showCreatorFab = false,
    this.onAddMoment,
  });

  final MomentsMediaFilter filter;
  final bool showCreatorFab;
  final VoidCallback? onAddMoment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(followingFeedProvider);
    return feedAsync.when(
      data: (feed) => _FilteredGridFeed(
        items: feed.items,
        previewEndIndex: feed.previewEndIndex,
        filter: filter,
        onLoadMore: () => ref.read(followingFeedProvider.notifier).loadMore(),
        onItemUpdated: (index, item) =>
            ref.read(followingFeedProvider.notifier).updateItem(index, item),
        onCreatorTap: (id) => openCreatorProfile(context, ref, id),
        onAddMoment: onAddMoment,
        reserveFabSpace: showCreatorFab,
        emptyMessage: 'No moments from people you follow yet',
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _FeedErrorMessage(message: 'Failed to load feed: $e'),
    );
  }
}

class _PopularFeedBody extends ConsumerWidget {
  const _PopularFeedBody({
    required this.filter,
    this.showCreatorFab = false,
    this.onAddMoment,
  });

  final MomentsMediaFilter filter;
  final bool showCreatorFab;
  final VoidCallback? onAddMoment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(popularFeedProvider);
    return feedAsync.when(
      data: (feed) => _FilteredGridFeed(
        items: feed.items,
        previewEndIndex: feed.previewEndIndex,
        filter: filter,
        onLoadMore: () => ref.read(popularFeedProvider.notifier).loadMore(),
        onItemUpdated: (index, item) =>
            ref.read(popularFeedProvider.notifier).updateItem(index, item),
        onCreatorTap: (id) => openCreatorProfile(context, ref, id),
        onAddMoment: onAddMoment,
        reserveFabSpace: showCreatorFab,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _FeedErrorMessage(message: 'Failed to load feed: $e'),
    );
  }
}

class _FeedErrorMessage extends StatelessWidget {
  const _FeedErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Text(
        message,
        style: TextStyle(color: scheme.onSurfaceVariant),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _FilteredGridFeed extends StatelessWidget {
  const _FilteredGridFeed({
    required this.items,
    required this.previewEndIndex,
    required this.filter,
    this.onLoadMore,
    required this.onItemUpdated,
    this.onCreatorTap,
    this.onAddMoment,
    this.reserveFabSpace = false,
    this.emptyMessage = 'No moments yet',
  });

  final List<MomentFeedItem> items;
  final int previewEndIndex;
  final MomentsMediaFilter filter;
  final VoidCallback? onLoadMore;
  final void Function(int index, MomentFeedItem item) onItemUpdated;
  final void Function(String creatorId)? onCreatorTap;
  final VoidCallback? onAddMoment;
  final bool reserveFabSpace;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final filtered = applyMediaFilter(items, filter);
    if (filtered.isEmpty && items.isNotEmpty) {
      return Center(
        child: Text(
          _filterEmptyMessage(filter),
          style: TextStyle(
            color: AppBrandGradients.momentsTabInactiveColor,
            fontSize: 14,
          ),
        ),
      );
    }
    return MomentsGridFeed(
      items: filtered,
      viewerItems: items,
      previewEndIndex: filteredPreviewEndIndex(items, filter, previewEndIndex),
      mediaFilter: filter,
      onLoadMore: onLoadMore,
      onItemUpdated: (index, item) {
        final originalIndex = items.indexWhere((i) => i.id == item.id);
        if (originalIndex >= 0) {
          onItemUpdated(originalIndex, item);
        }
      },
      onCreatorTap: onCreatorTap,
      onAddMoment: onAddMoment,
      reserveFabSpace: reserveFabSpace,
      emptyMessage: emptyMessage,
      onReport: (item) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Thank you.')),
        );
      },
    );
  }

  String _filterEmptyMessage(MomentsMediaFilter filter) {
    switch (filter) {
      case MomentsMediaFilter.photos:
        return 'No photo moments yet';
      case MomentsMediaFilter.videos:
        return 'No video moments yet';
      case MomentsMediaFilter.all:
        return emptyMessage;
    }
  }
}
