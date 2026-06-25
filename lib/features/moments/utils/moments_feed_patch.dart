import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/moments_models.dart';
import '../providers/moments_providers.dart';

/// @deprecated Per-moment unlock removed — refresh feeds after premium purchase instead.
void applyUnlockedMomentToFeeds(dynamic ref, MomentFeedItem unlocked) {
  if (ref is! Ref) return;
  ref.invalidate(popularFeedProvider);
  ref.invalidate(followingFeedProvider);
}
