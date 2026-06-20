import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/moments_models.dart';
import '../providers/moments_providers.dart';

void applyUnlockedMomentToFeeds(dynamic ref, MomentFeedItem unlocked) {
  void patchFeed(
    List<MomentFeedItem>? items,
    void Function(int index, MomentFeedItem item) updateItem,
  ) {
    if (items == null) return;
    final index = items.indexWhere((item) => item.id == unlocked.id);
    if (index < 0) return;
    updateItem(index, unlocked);
  }

  patchFeed(
    ref.read(popularFeedProvider).valueOrNull,
    (index, item) =>
        ref.read(popularFeedProvider.notifier).updateItem(index, item),
  );
  patchFeed(
    ref.read(followingFeedProvider).valueOrNull,
    (index, item) =>
        ref.read(followingFeedProvider.notifier).updateItem(index, item),
  );
}
