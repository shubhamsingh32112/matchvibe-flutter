import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../account/providers/moments_premium_provider.dart';

Future<void> launchMomentsPremiumCheckout(
  BuildContext context,
  WidgetRef ref, {
  String? planId,
}) async {
  try {
    final plans = await ref.read(momentsPremiumPlansProvider.future);
    final selectedId = planId ??
        plans.defaultPlan?.planId ??
        (plans.activePlans.isNotEmpty ? plans.activePlans.first.planId : null);
    if (selectedId == null) {
      if (context.mounted) {
        AppToast.showError(context, 'No Moments Premium plan available');
      }
      return;
    }
    final url = await ref
        .read(momentsPremiumApiServiceProvider)
        .initiateCheckout(planId: selectedId);
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      AppToast.showError(context, 'Could not open checkout');
    }
  } catch (_) {
    if (context.mounted) {
      AppToast.showError(context, 'Failed to start Moments Premium checkout');
    }
  }
}
