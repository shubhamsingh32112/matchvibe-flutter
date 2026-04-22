import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../../shared/widgets/skeleton_card.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../providers/favorite_creators_provider.dart';
import '../widgets/home_user_grid_card.dart';

class FavoriteCreatorsScreen extends ConsumerStatefulWidget {
  const FavoriteCreatorsScreen({super.key});

  @override
  ConsumerState<FavoriteCreatorsScreen> createState() =>
      _FavoriteCreatorsScreenState();
}

class _FavoriteCreatorsScreenState extends ConsumerState<FavoriteCreatorsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 600) return;
    final meta = ref.read(favoriteCreatorsFeedMetaProvider);
    if (meta.hasMore && !meta.isLoadingMore) {
      ref.read(favoriteCreatorsProvider.notifier).loadMore();
    }
  }

  SliverGridDelegate _gridDelegate(double width) {
    int crossAxisCount = 2;
    double aspectRatio = 0.70;
    if (width >= 1200) {
      crossAxisCount = 5;
      aspectRatio = 0.82;
    } else if (width >= 900) {
      crossAxisCount = 4;
      aspectRatio = 0.78;
    } else if (width >= 640) {
      crossAxisCount = 3;
      aspectRatio = 0.74;
    }
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: AppSpacing.xs,
      mainAxisSpacing: AppSpacing.xs,
      childAspectRatio: aspectRatio,
    );
  }

  @override
  Widget build(BuildContext context) {
    final creatorsAsync = ref.watch(favoriteCreatorsProvider);
    final meta = ref.watch(favoriteCreatorsFeedMetaProvider);

    return AppScaffold(
      appBar: buildBrandAppBar(context, title: 'Favorite Creators'),
      child: creatorsAsync.when(
        loading: () => LayoutBuilder(
          builder: (context, constraints) => GridView.builder(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            gridDelegate: _gridDelegate(constraints.maxWidth),
            itemCount: 6,
            itemBuilder: (context, index) => const SkeletonCard(),
          ),
        ),
        error: (error, stack) => ErrorState(
          title: 'Unable to load favorites',
          message: UserMessageMapper.userMessageFor(
            error,
            fallback: 'Couldn\'t load favorites. Please try again.',
          ),
          actionLabel: 'Retry',
          onAction: () => ref.read(favoriteCreatorsProvider.notifier).refreshFeed(),
        ),
        data: (creators) {
          if (creators.isEmpty) {
            return EmptyState(
              icon: Icons.favorite_border,
              title: 'No favorites yet',
              message: 'Tap the heart on creators to add them here.',
              actionLabel: 'Refresh',
              onAction: () =>
                  ref.read(favoriteCreatorsProvider.notifier).refreshFeed(),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(favoriteCreatorsProvider.notifier).refreshFeed();
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: LayoutBuilder(
              builder: (context, constraints) => CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    sliver: SliverGrid(
                      gridDelegate: _gridDelegate(constraints.maxWidth),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final creator = creators[index];
                        return HomeUserGridCard(creator: creator);
                      }, childCount: creators.length),
                    ),
                  ),
                  if (meta.hasMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12, bottom: 20),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
