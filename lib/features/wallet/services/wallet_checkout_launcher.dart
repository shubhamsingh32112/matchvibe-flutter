import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static Future<void> startCheckoutForCoins(
    BuildContext context,
    int coins,
  ) async {
    if (!context.mounted) return;

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
