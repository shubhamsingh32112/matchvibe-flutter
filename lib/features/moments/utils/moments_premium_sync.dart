import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/providers/moments_premium_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/moments_providers.dart';

/// Refreshes auth + premium status after checkout; retries if webhook/verify races the deep link.
Future<bool> syncMomentsPremiumAfterPurchase(
  ProviderContainer container, {
  int maxAttempts = 5,
}) async {
  for (var i = 0; i < maxAttempts; i++) {
    await container.read(authProvider.notifier).refreshUser();
    try {
      final status =
          await container.read(momentsPremiumApiServiceProvider).fetchStatus();
      if (status.active) {
        invalidateMomentsFeeds(container);
        container.invalidate(momentsPremiumStatusProvider);
        return true;
      }
    } catch (_) {
      // Retry on transient errors.
    }
    if (i < maxAttempts - 1) {
      await Future<void>.delayed(Duration(milliseconds: 400 * (i + 1)));
    }
  }
  invalidateMomentsFeeds(container);
  container.invalidate(momentsPremiumStatusProvider);
  return false;
}

/// On resume: if premium expiry passed while app was backgrounded, refresh immediately.
Future<void> syncMomentsPremiumIfExpired(ProviderContainer container) async {
  final expiresAt =
      container.read(authProvider).user?.momentsPremiumStatus.expiresAt;
  if (expiresAt == null) return;
  if (!DateTime.now().isAfter(expiresAt)) return;
  await container.read(authProvider.notifier).refreshUser();
  invalidateMomentsFeeds(container);
  container.invalidate(momentsPremiumStatusProvider);
}
