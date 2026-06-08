import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_toast.dart';
import '../providers/moments_providers.dart';
import '../services/moments_api_service.dart';

Future<bool> confirmDeleteMoment(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete post?'),
      content: const Text(
        'This removes the post from feeds. Paid posts stay accessible to users who already purchased.',
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
  return ok == true;
}

Future<bool> confirmDeleteStory(BuildContext context) async {
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
  return ok == true;
}

Future<bool> deleteMomentWithRefresh(
  WidgetRef ref,
  BuildContext context,
  String momentId, {
  String? creatorId,
}) async {
  if (!await confirmDeleteMoment(context)) return false;
  try {
    await MomentsApiService().deleteMoment(momentId);
    ref.invalidate(storiesBarProvider);
    ref.invalidate(followingFeedProvider);
    ref.invalidate(popularFeedProvider);
    ref.invalidate(myMomentsProvider);
    ref.invalidate(creatorMomentsAnalyticsProvider);
    if (creatorId != null && creatorId.isNotEmpty) {
      ref.invalidate(creatorMomentsProvider(creatorId));
    }
    if (context.mounted) {
      AppToast.showSuccess(context, 'Post deleted');
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      AppToast.showError(context, 'Could not delete post. Please try again.');
    }
    return false;
  }
}

Future<bool> deleteStoryWithRefresh(
  WidgetRef ref,
  BuildContext context,
  String storyId,
) async {
  if (!await confirmDeleteStory(context)) return false;
  try {
    await StoriesApiService().deleteStory(storyId);
    ref.invalidate(myStoriesProvider);
    ref.invalidate(storiesBarProvider);
    if (context.mounted) {
      AppToast.showSuccess(context, 'Story deleted');
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      AppToast.showError(context, 'Could not delete story. Please try again.');
    }
    return false;
  }
}
