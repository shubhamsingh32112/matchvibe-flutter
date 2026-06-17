import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../providers/moments_providers.dart';
import '../utils/moment_owner_actions.dart';
import '../widgets/moment_status_badge.dart';
import '../widgets/moments_upload_flow.dart';
import 'story_viewers_screen.dart';

class MyMomentsScreen extends ConsumerStatefulWidget {
  const MyMomentsScreen({super.key});

  @override
  ConsumerState<MyMomentsScreen> createState() => _MyMomentsScreenState();
}

class _MyMomentsScreenState extends ConsumerState<MyMomentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onFabPressed() {
    switch (_tabController.index) {
      case 0:
        startStoryUploadFlow(context, ref);
      case 1:
        startMomentUploadFlow(context, ref);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabIndex = _tabController.index;
    final showFab = tabIndex == 0 || tabIndex == 1;

    return Scaffold(
      backgroundColor: AppBrandGradients.accountMenuPageBackground,
      appBar: buildAccountFlowAppBar(
        context,
        title: 'My Moments',
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Stories'),
            Tab(text: 'Posts'),
            Tab(text: 'Analytics'),
          ],
        ),
      ),
      floatingActionButton: showFab
          ? FloatingActionButton(
              backgroundColor: AppBrandGradients.accountMenuIconTint,
              foregroundColor: Colors.white,
              onPressed: _onFabPressed,
              child: const Icon(Icons.add),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MyStoriesTab(),
          _MyPostsTab(),
          _AnalyticsTab(),
        ],
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
                  'Unique views: ${story.viewsCount ?? 0} · Expires ${DateTime.tryParse(story.expiresAt)?.toLocal()}',
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
                      await deleteStoryWithRefresh(ref, context, story.id);
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
                  '${paid ? 'Paid' : 'Free'} · Unique views: ${moment.viewsCount ?? 0} · '
                  'Purchases: ${moment.purchaseCount ?? 0}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => deleteMomentWithRefresh(
                    ref,
                    context,
                    moment.id,
                    creatorId: moment.creatorId,
                  ),
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
                  '${data['totalViews'] ?? 0} unique views · '
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
                              'Unique views: ${m.viewsCount ?? 0} · Purchases: ${m.purchaseCount ?? 0}',
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
