import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/meta_app_events_service.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../../shared/widgets/app_toast.dart';
import '../services/payment_service.dart';

/// Opens the same web checkout flow as [WalletScreen._addCoins], for reuse
/// from modals and other entry points.
class WalletCheckoutLauncher {
  WalletCheckoutLauncher._();

  static final PaymentService _paymentService = PaymentService();

  /// Starts checkout for the pack that grants [coins]. Shows a blocking
  /// loading indicator on [context]'s navigator while awaiting the API.
  ///
  /// When [priceInr] is provided, logs Meta AddToCart before initiating checkout.
  static Future<void> startCheckoutForCoins(
    BuildContext context,
    int coins, {
    int? priceInr,
  }) async {
    if (!context.mounted) return;

    if (priceInr != null && priceInr > 0) {
      await MetaAppEventsService.logAddToCart(
        contentId: 'coins_$coins',
        priceInr: priceInr.toDouble(),
      );
    }

    var loadingVisible = false;
    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );
      loadingVisible = true;

      final checkoutData = await _paymentService.initiateWebCheckout(coins);
      final checkoutUrl = checkoutData['checkoutUrl'] as String;
      final sessionId = checkoutData['sessionId'] as String? ?? '';
      final packageId = checkoutData['packageId'] as String? ?? 'coins_$coins';
      final resolvedCoins = checkoutData['coins'] as int? ?? coins;
      final resolvedPriceInr = checkoutData['priceInr'] as int? ?? priceInr ?? 0;

      MetaAppEventsService.setPendingCheckout(
        MetaPendingCheckout(
          sessionId: sessionId,
          packageId: packageId,
          coins: resolvedCoins,
          priceInr: resolvedPriceInr,
        ),
      );
      if (resolvedPriceInr > 0) {
        await MetaAppEventsService.logInitiateCheckout(
          contentId: packageId,
          priceInr: resolvedPriceInr.toDouble(),
          sessionId: sessionId.isNotEmpty ? sessionId : null,
        );
      }

      if (context.mounted && loadingVisible) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingVisible = false;
      }

      final uri = Uri.parse(checkoutUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        MetaAppEventsService.takePendingCheckout();
        throw Exception('Unable to open checkout website');
      }

      if (context.mounted) {
        AppToast.showInfo(
          context,
          'Complete payment on the website. App will reopen automatically.',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      MetaAppEventsService.takePendingCheckout();
      if (context.mounted && loadingVisible) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingVisible = false;
      }
      if (context.mounted) {
        AppToast.showError(
          context,
          UserMessageMapper.userMessageFor(
            e,
            fallback: 'Couldn\'t start checkout. Please try again.',
          ),
          duration: const Duration(seconds: 3),
        );
      }
    }
  }
}
