import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/moments_providers.dart';

void syncFollowState(
  dynamic ref, {
  required String creatorId,
  required bool isFollowing,
}) {
  ref.read(popularFeedProvider.notifier).patchFollowStateForCreator(
        creatorId,
        isFollowing,
      );
  ref.read(followingFeedProvider.notifier).patchFollowStateForCreator(
        creatorId,
        isFollowing,
      );
  ref.invalidate(creatorSummaryProvider(creatorId));
  ref.invalidate(creatorMomentsProvider(creatorId));
  ref.invalidate(followingCreatorsProvider);
  ref.invalidate(followingFeedProvider);
}
