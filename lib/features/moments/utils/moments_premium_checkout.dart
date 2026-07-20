import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/meta_app_events_service.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../account/models/moments_premium_models.dart';
import '../../account/providers/moments_premium_provider.dart';

Future<void> launchMomentsPremiumCheckout(
  BuildContext context,
  WidgetRef ref, {
  String? planId,
}) async {
  try {
    final plans = await ref.read(momentsPremiumPlansProvider.future);
    MomentsPremiumPlanOption? selected;
    if (planId != null) {
      for (final plan in plans.activePlans) {
        if (plan.planId == planId) {
          selected = plan;
          break;
        }
      }
    }
    selected ??=
        plans.defaultPlan ??
        (plans.activePlans.isNotEmpty ? plans.activePlans.first : null);
    if (selected == null) {
      if (context.mounted) {
        AppToast.showError(context, 'No Moments Premium plan available');
      }
      return;
    }

    final selectedId = selected.planId;
    final priceInr = selected.priceInr;

    if (priceInr > 0) {
      await MetaAppEventsService.logAddToCart(
        contentId: selectedId,
        priceInr: priceInr.toDouble(),
        contentType: 'moments_premium',
      );
    }

    final checkout = await ref
        .read(momentsPremiumApiServiceProvider)
        .initiateCheckout(planId: selectedId);
    final checkoutUrl = checkout['checkoutUrl'] as String;
    final sessionId = checkout['sessionId'] as String? ?? '';
    final resolvedPlanId = checkout['planId'] as String? ?? selectedId;
    final resolvedPriceInr = checkout['priceInr'] as int? ?? priceInr;

    MetaAppEventsService.setPendingCheckout(
      MetaPendingCheckout(
        sessionId: sessionId,
        packageId: resolvedPlanId,
        priceInr: resolvedPriceInr,
        contentType: 'moments_premium',
      ),
    );
    if (resolvedPriceInr > 0) {
      await MetaAppEventsService.logInitiateCheckout(
        contentId: resolvedPlanId,
        priceInr: resolvedPriceInr.toDouble(),
        contentType: 'moments_premium',
        sessionId: sessionId.isNotEmpty ? sessionId : null,
      );
    }

    final launched = await launchUrl(
      Uri.parse(checkoutUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      MetaAppEventsService.takePendingCheckout();
      if (context.mounted) {
        AppToast.showError(context, 'Could not open checkout');
      }
    }
  } catch (_) {
    MetaAppEventsService.takePendingCheckout();
    if (context.mounted) {
      AppToast.showError(context, 'Failed to start Moments Premium checkout');
    }
  }
}
