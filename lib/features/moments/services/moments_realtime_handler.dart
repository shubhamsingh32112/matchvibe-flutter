import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/moments_providers.dart';
import '../utils/moments_follow_sync.dart';

void handleMomentsSocketEvent(Ref ref, String event, Map<String, dynamic> data) {
  switch (event) {
    case 'story:uploaded':
      ref.invalidate(storiesBarProvider);
      debugPrint('📸 [MOMENTS] story:uploaded');
      break;
    case 'moment:uploaded':
      ref.invalidate(popularFeedProvider);
      ref.invalidate(followingFeedProvider);
      debugPrint('🎬 [MOMENTS] moment:uploaded');
      break;
    case 'moment:purchase_count':
      ref.invalidate(myMomentsProvider);
      ref.invalidate(creatorMomentsAnalyticsProvider);
      debugPrint('💰 [MOMENTS] moment:purchase_count ${data['momentId']}');
      break;
    case 'creator:followed':
      final creatorId = data['creatorId']?.toString();
      final followerUserId = data['followerUserId']?.toString();
      final currentUserId = ref.read(authProvider).user?.id;
      if (creatorId != null &&
          creatorId.isNotEmpty &&
          followerUserId != null &&
          followerUserId.isNotEmpty &&
          currentUserId == followerUserId) {
        syncFollowState(
          ref,
          creatorId: creatorId,
          isFollowing: data['isFollowing'] as bool? ?? true,
        );
      }
      debugPrint('👤 [MOMENTS] creator:followed $creatorId');
      break;
    case 'media:ready':
      final sessionId = data['sessionId']?.toString();
      if (sessionId != null && sessionId.isNotEmpty) {
        final pending = ref.read(pendingMediaSessionsProvider);
        if (pending.contains(sessionId)) {
          ref.read(pendingMediaSessionsProvider.notifier).state =
              pending.where((id) => id != sessionId).toSet();
          invalidateMomentsFeeds(ref.container);
        }
      }
      debugPrint('✅ [MOMENTS] media:ready $sessionId');
      break;
  }
}
