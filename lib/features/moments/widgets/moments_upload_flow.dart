import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/moments_models.dart';
import '../screens/moments_upload_review_screen.dart';
import '../services/moments_upload_coordinator.dart';

final _coordinator = MomentsUploadCoordinator();

Future<void> startStoryUploadFlow(BuildContext context, WidgetRef ref) {
  return _startUploadFlow(
    context,
    contentType: MomentsUploadContentType.story,
  );
}

Future<void> startMomentUploadFlow(BuildContext context, WidgetRef ref) {
  return _startUploadFlow(
    context,
    contentType: MomentsUploadContentType.moment,
  );
}

Future<void> _startUploadFlow(
  BuildContext context, {
  required MomentsUploadContentType contentType,
}) async {
  final picked = await _coordinator.pickGalleryMedia();
  if (picked == null || !context.mounted) return;

  final classified = _coordinator.classify(picked);
  if (!context.mounted) return;

  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (ctx) => MomentsUploadReviewScreen(
        contentType: contentType,
        file: classified.file,
        mediaKind: classified.kind,
        onUploadComplete: ({required isStory, required rewardCoins}) {
          if (!ctx.mounted) return;
          if (isStory) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('Story uploaded')),
            );
            return;
          }
          final rewardText =
              rewardCoins > 0 ? ' · +$rewardCoins coins earned' : '';
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text('Moment posted$rewardText')),
          );
        },
      ),
    ),
  );
}
