import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/moments_providers.dart';

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
    case 'moment:purchased':
      ref.invalidate(popularFeedProvider);
      debugPrint('💰 [MOMENTS] moment:purchased ${data['momentId']}');
      break;
    case 'creator:followed':
      final creatorId = data['creatorId']?.toString();
      if (creatorId != null && creatorId.isNotEmpty) {
        ref.invalidate(creatorSummaryProvider(creatorId));
      }
      ref.invalidate(followingCreatorsProvider);
      ref.invalidate(followingFeedProvider);
      debugPrint('👤 [MOMENTS] creator:followed $creatorId');
      break;
    case 'media:ready':
      final sessionId = data['sessionId']?.toString();
      if (sessionId != null && sessionId.isNotEmpty) {
        final pending = ref.read(pendingMediaSessionsProvider);
        if (pending.contains(sessionId)) {
          ref.read(pendingMediaSessionsProvider.notifier).state =
              pending.where((id) => id != sessionId).toSet();
          invalidateMomentsFeeds(ref);
        }
      }
      debugPrint('✅ [MOMENTS] media:ready $sessionId');
      break;
  }
}
