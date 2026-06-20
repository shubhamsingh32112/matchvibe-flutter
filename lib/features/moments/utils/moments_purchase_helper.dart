import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/user_message_mapper.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/moments_models.dart';
import '../services/moments_api_service.dart';
import 'moments_feed_patch.dart';

String momentUnlockLabel(MomentFeedItem item) {
  if (item.vipFreeUnlockAvailable == true ||
      item.media.vipFreeUnlockAvailable == true) {
    return 'VIP Free Unlock';
  }
  if (item.discountApplied == true || item.media.discountApplied == true) {
    final original = item.originalPriceCoins ?? item.media.originalPriceCoins;
    final price = item.unlockPriceCoins ?? item.media.unlockPriceCoins ?? 0;
    if (original != null && original > price) {
      return 'VIP: $price Coins (was $original)';
    }
    return 'VIP: $price Coins';
  }
  final price = item.unlockPriceCoins ?? item.media.unlockPriceCoins ?? 0;
  return 'Unlock for $price Coins';
}

Future<MomentFeedItem?> purchaseMomentWithFeedback(
  BuildContext context,
  WidgetRef ref,
  MomentFeedItem item, {
  bool retryOnConflict = true,
}) async {
  final api = MomentsApiService();
  try {
    final unlocked = await api.purchase(item.id);
    await ref.read(authProvider.notifier).refreshUser();
    applyUnlockedMomentToFeeds(ref, unlocked);
    return unlocked;
  } on DioException catch (e) {
    final code = e.response?.statusCode ?? 0;
    if (code == 409 && retryOnConflict) {
      final recovered = await _recoverFromPurchaseConflict(context, ref, api, item.id);
      if (recovered != null) return recovered;
    }
    if (context.mounted) {
      _showPurchaseError(context, ref, e);
    }
    return null;
  } catch (e) {
    if (context.mounted) {
      _showPurchaseError(context, ref, e);
    }
    return null;
  }
}

Future<MomentFeedItem?> _recoverFromPurchaseConflict(
  BuildContext context,
  WidgetRef ref,
  MomentsApiService api,
  String momentId,
) async {
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  try {
    final refreshed = await api.fetchMomentDetail(momentId);
    if (!refreshed.locked) {
      await ref.read(authProvider.notifier).refreshUser();
      applyUnlockedMomentToFeeds(ref, refreshed);
      return refreshed;
    }
  } catch (_) {
    // Fall through to one purchase retry.
  }

  try {
    final unlocked = await api.purchase(momentId);
    await ref.read(authProvider.notifier).refreshUser();
    applyUnlockedMomentToFeeds(ref, unlocked);
    return unlocked;
  } catch (retryError) {
    if (context.mounted) {
      _showPurchaseError(context, ref, retryError);
    }
    return null;
  }
}

void _showPurchaseError(BuildContext context, WidgetRef ref, Object error) {
  if (!context.mounted) return;
  final message = UserMessageMapper.userMessageFor(
    error,
    fallback: 'Purchase failed. Please try again.',
  );
  if (message.toLowerCase().contains('insufficient coins')) {
    final role = ref.read(authProvider).user?.role;
    if (role == 'user') {
      context.push('/wallet');
      return;
    }
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
