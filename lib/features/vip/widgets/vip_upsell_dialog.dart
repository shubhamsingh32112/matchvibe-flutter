import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/styles/app_brand_styles.dart';

const _defaultMessage = 'Become a VIP member for exclusive features';

Future<void> showVipExclusiveFeatureDialog(
  BuildContext context, {
  String? message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: AppBrandGradients.vipBadgeGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.workspace_premium_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      title: const Text('VIP Exclusive'),
      content: Text(message ?? _defaultMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Become VIP'),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    context.push('/vip');
  }
}
