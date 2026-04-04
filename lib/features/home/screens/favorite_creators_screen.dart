import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../../shared/widgets/skeleton_card.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../providers/home_provider.dart';
import '../widgets/home_user_grid_card.dart';

class FavoriteCreatorsScreen extends ConsumerWidget {
  const FavoriteCreatorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creatorsAsync = ref.watch(creatorsProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Favorite Creators'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      child: creatorsAsync.when(
        loading: () => GridView.builder(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.xs,
            mainAxisSpacing: AppSpacing.xs,
            childAspectRatio: 0.70,
          ),
          itemCount: 6,
          itemBuilder: (context, index) => const SkeletonCard(),
        ),
        error: (error, stack) => ErrorState(
          title: 'Unable to load favorites',
          message: UserMessageMapper.userMessageFor(
            error,
            fallback: 'Couldn\'t load favorites. Please try again.',
          ),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(creatorsProvider),
        ),
        data: (creators) {
          final favoriteCreators =
              creators.where((creator) => creator.isFavorite).toList();

          if (favoriteCreators.isEmpty) {
            return EmptyState(
              icon: Icons.favorite_border,
              title: 'No favorites yet',
              message: 'Tap the heart on creators to add them here.',
              actionLabel: 'Refresh',
              onAction: () => ref.invalidate(creatorsProvider),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(creatorsProvider);
              ref.invalidate(homeFeedProvider);
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: GridView.builder(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.xs,
                mainAxisSpacing: AppSpacing.xs,
                childAspectRatio: 0.70,
              ),
              itemCount: favoriteCreators.length,
              itemBuilder: (context, index) {
                final creator = favoriteCreators[index];
                return HomeUserGridCard(creator: creator);
              },
            ),
          );
        },
      ),
    );
  }
}
