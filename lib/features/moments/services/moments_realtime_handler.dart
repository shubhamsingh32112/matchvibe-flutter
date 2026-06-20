import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/moments_models.dart';
import '../providers/moments_providers.dart';
import '../services/moments_api_service.dart';
import '../utils/moments_feed_patch.dart';
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
    case 'moment:purchased':
      _handleMomentPurchased(ref, data);
      debugPrint('💰 [MOMENTS] moment:purchased ${data['momentId']}');
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
          invalidateMomentsFeeds(ref);
        }
      }
      debugPrint('✅ [MOMENTS] media:ready $sessionId');
      break;
  }
}

void _handleMomentPurchased(Ref ref, Map<String, dynamic> data) {
  final buyerUserId = data['buyerUserId']?.toString();
  final currentUserId = ref.read(authProvider).user?.id;
  if (buyerUserId == null ||
      buyerUserId.isEmpty ||
      currentUserId != buyerUserId) {
    return;
  }

  final rawItem = data['item'];
  if (rawItem is Map) {
    try {
      final unlocked = MomentFeedItem.fromJson(
        Map<String, dynamic>.from(rawItem),
      );
      applyUnlockedMomentToFeeds(ref, unlocked);
      return;
    } catch (e) {
      debugPrint('⚠️ [MOMENTS] moment:purchased item parse failed: $e');
    }
  }

  final momentId = data['momentId']?.toString();
  if (momentId != null && momentId.isNotEmpty) {
    unawaited(_refetchUnlockedMoment(ref, momentId));
  }
}

Future<void> _refetchUnlockedMoment(Ref ref, String momentId) async {
  try {
    final unlocked = await MomentsApiService().fetchMomentDetail(momentId);
    applyUnlockedMomentToFeeds(ref, unlocked);
  } catch (e) {
    debugPrint('⚠️ [MOMENTS] moment refetch after purchase failed: $e');
    ref.invalidate(popularFeedProvider);
    ref.invalidate(followingFeedProvider);
  }
}
