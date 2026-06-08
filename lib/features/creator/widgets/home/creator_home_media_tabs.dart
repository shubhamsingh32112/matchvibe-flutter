import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../moments/models/moments_models.dart';
import '../../../moments/providers/moments_providers.dart';
import '../../../moments/screens/creator_moment_viewer_screen.dart';
import '../../../moments/utils/moment_owner_actions.dart';
import '../../../moments/widgets/moment_upload_sheet.dart';
import '../../constants/creator_home_assets.dart';
import '../../providers/creator_dashboard_provider.dart';
import '../../theme/creator_home_tokens.dart';
import '../../utils/creator_home_formatters.dart';

class CreatorHomeMediaTabs extends ConsumerStatefulWidget {
  const CreatorHomeMediaTabs({super.key});

  @override
  ConsumerState<CreatorHomeMediaTabs> createState() =>
      _CreatorHomeMediaTabsState();
}

class _CreatorHomeMediaTabsState extends ConsumerState<CreatorHomeMediaTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final momentsAsync = ref.watch(myMomentsProvider);
    final creatorId = ref.watch(
      creatorDashboardProvider.select((a) => a.valueOrNull?.creatorProfile.id),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          labelColor: CreatorHomeTokens.pinkAccent,
          unselectedLabelColor: CreatorHomeTokens.labelGrey,
          indicatorColor: CreatorHomeTokens.pinkAccent,
          tabs: [
            Tab(
              icon: _CreatorMediaTabIcon(
                controller: _tabController,
                tabIndex: 0,
                assetPath: CreatorHomeAssets.reelsTab,
                fallbackIcon: Icons.play_circle_outline,
              ),
              text: 'Reels',
            ),
            Tab(
              icon: _CreatorMediaTabIcon(
                controller: _tabController,
                tabIndex: 1,
                assetPath: CreatorHomeAssets.postsTab,
                fallbackIcon: Icons.article_outlined,
              ),
              text: 'Posts',
            ),
          ],
        ),
        const SizedBox(height: 8),
        momentsAsync.when(
          data: (items) {
            final reels = items.where((i) => i.media.isVideo).toList();
            final posts = items.where((i) => !i.media.isVideo).toList();
            return SizedBox(
              height: 360,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _MediaGrid(
                    items: reels,
                    isVideo: true,
                    creatorId: creatorId,
                  ),
                  _MediaGrid(
                    items: posts,
                    isVideo: false,
                    creatorId: creatorId,
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => SizedBox(
            height: 120,
            child: Center(
              child: TextButton(
                onPressed: () => ref.invalidate(myMomentsProvider),
                child: const Text('Retry loading media'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CreatorMediaTabIcon extends StatelessWidget {
  const _CreatorMediaTabIcon({
    required this.controller,
    required this.tabIndex,
    required this.assetPath,
    required this.fallbackIcon,
  });

  final TabController controller;
  final int tabIndex;
  final String assetPath;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selected = controller.index == tabIndex;
        return Opacity(
          opacity: selected ? 1 : 0.45,
          child: Image.asset(
            assetPath,
            width: 22,
            height: 22,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => Icon(
              fallbackIcon,
              size: 18,
              color: selected
                  ? CreatorHomeTokens.pinkAccent
                  : CreatorHomeTokens.labelGrey,
            ),
          ),
        );
      },
    );
  }
}

class _MediaGrid extends ConsumerWidget {
  const _MediaGrid({
    required this.items,
    required this.isVideo,
    required this.creatorId,
  });

  final List<MomentFeedItem> items;
  final bool isVideo;
  final String? creatorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: () => showMomentUploadSheet(context),
          icon: const Icon(Icons.add),
          label: Text(isVideo ? 'Upload a reel' : 'Upload a post'),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.56,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final views = item.viewsCount ?? 0;
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CreatorMomentViewerScreen(
                      items: items,
                      initialIndex: index,
                      allowOwnerDelete: true,
                      creatorId: creatorId,
                    ),
                  ),
                );
              },
              onLongPress: () async {
                await deleteMomentWithRefresh(
                  ref,
                  context,
                  item.id,
                  creatorId: creatorId ?? item.creatorId,
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    item.media.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => ColoredBox(
                      color: CreatorHomeTokens.bannerLavender,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                  if (isVideo)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 16,
                          ),
                          Text(
                            formatViewCount(views),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          await deleteMomentWithRefresh(
                            ref,
                            context,
                            item.id,
                            creatorId: creatorId ?? item.creatorId,
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
