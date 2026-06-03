import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../providers/moments_providers.dart';
import '../services/moments_api_service.dart';
import '../widgets/moment_status_badge.dart';
import '../widgets/moment_upload_sheet.dart';
import 'story_viewers_screen.dart';

class MyMomentsScreen extends ConsumerWidget {
  const MyMomentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppBrandGradients.accountMenuPageBackground,
        appBar: buildAccountFlowAppBar(
          context,
          title: 'My Moments',
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Stories'),
              Tab(text: 'Posts'),
              Tab(text: 'Analytics'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppBrandGradients.accountMenuIconTint,
          foregroundColor: Colors.white,
          onPressed: () => showMomentUploadSheet(context),
          child: const Icon(Icons.add),
        ),
        body: const TabBarView(
          children: [
            _MyStoriesTab(),
            _MyPostsTab(),
            _AnalyticsTab(),
          ],
        ),
      ),
    );
  }
}

class _MyStoriesTab extends ConsumerWidget {
  const _MyStoriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(myStoriesProvider);
    return storiesAsync.when(
      data: (stories) {
        if (stories.isEmpty) {
          return const Center(child: Text('No active stories'));
        }
        final api = StoriesApiService();
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: stories.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final story = stories[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppBrandGradients.accountMenuCardShadow,
              ),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    story.media.thumbnailUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text('${story.type.toUpperCase()} story'),
                    ),
                    MomentStatusBadge(
                      processingStatus: story.processingStatus,
                      moderationStatus: story.moderationStatus,
                      mediaProcessingStatus: story.media.processingStatus,
                    ),
                  ],
                ),
                subtitle: Text(
                  'Views: ${story.viewsCount ?? 0} · Expires ${DateTime.tryParse(story.expiresAt)?.toLocal()}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'viewers') {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => StoryViewersScreen(storyId: story.id),
                        ),
                      );
                    } else if (value == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete story?'),
                          content: const Text('This cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await api.deleteStory(story.id);
                        ref.invalidate(myStoriesProvider);
                        ref.invalidate(storiesBarProvider);
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'viewers', child: Text('View viewers')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed: $e')),
    );
  }
}

class _MyPostsTab extends ConsumerWidget {
  const _MyPostsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final momentsAsync = ref.watch(myMomentsProvider);
    return momentsAsync.when(
      data: (moments) {
        if (moments.isEmpty) {
          return const Center(child: Text('No posts yet'));
        }
        final api = MomentsApiService();
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: moments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final moment = moments[index];
            final paid = moment.accessType == 'paid';
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppBrandGradients.accountMenuCardShadow,
              ),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    moment.media.thumbnailUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(moment.media.isVideo ? 'Video' : 'Photo'),
                    ),
                    MomentStatusBadge(
                      processingStatus: moment.processingStatus,
                      moderationStatus: moment.moderationStatus,
                      mediaProcessingStatus: moment.media.processingStatus,
                    ),
                  ],
                ),
                subtitle: Text(
                  '${paid ? 'Paid' : 'Free'} · Views: ${moment.viewsCount ?? 0} · '
                  'Purchases: ${moment.purchaseCount ?? 0}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete post?'),
                        content: const Text(
                          'Paid posts remain accessible to users who already purchased.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await api.deleteMoment(moment.id);
                      ref.invalidate(myMomentsProvider);
                      ref.invalidate(forYouFeedProvider);
                      ref.invalidate(creatorMomentsAnalyticsProvider);
                    }
                  },
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed: $e')),
    );
  }
}

class _AnalyticsTab extends ConsumerWidget {
  const _AnalyticsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(creatorMomentsAnalyticsProvider);
    final momentsAsync = ref.watch(myMomentsProvider);
    return analytics.when(
      data: (data) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppBrandGradients.accountMenuCardShadow,
              ),
              child: ListTile(
                title: const Text('Moments earnings'),
                subtitle: Text(
                  '${data['momentsEarnings'] ?? 0} coins · '
                  '${data['purchaseCount'] ?? 0} purchases · '
                  '${data['totalViews'] ?? 0} views · '
                  '${data['postCount'] ?? 0} posts',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Per post',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            momentsAsync.when(
              data: (moments) {
                if (moments.isEmpty) {
                  return const Text('No posts yet');
                }
                return Column(
                  children: moments
                      .map(
                        (m) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: AppBrandGradients.accountMenuCardShadow,
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.perm_media_outlined),
                            title: Text(m.caption?.isNotEmpty == true
                                ? m.caption!
                                : (m.media.isVideo ? 'Video' : 'Photo')),
                            subtitle: Text(
                              'Views: ${m.viewsCount ?? 0} · Purchases: ${m.purchaseCount ?? 0}',
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Posts unavailable: $e'),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Analytics unavailable: $e')),
    );
  }
}
