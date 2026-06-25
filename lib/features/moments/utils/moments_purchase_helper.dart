import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/moments_models.dart';
import 'moments_paywall.dart';

/// @deprecated Coin purchases removed — use Moments Premium subscription.
String momentUnlockLabel(MomentFeedItem item) => 'Unlock Moments Premium';

Future<MomentFeedItem?> purchaseMomentWithFeedback(
  BuildContext context,
  WidgetRef ref,
  MomentFeedItem item, {
  bool retryOnConflict = true,
}) async {
  await showMomentsPremiumSheet(context, ref);
  return null;
}
