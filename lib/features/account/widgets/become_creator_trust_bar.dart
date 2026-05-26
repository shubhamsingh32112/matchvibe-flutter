import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../shared/styles/app_brand_styles.dart';

class BecomeCreatorTrustBar extends StatelessWidget {
  const BecomeCreatorTrustBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E5F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 18,
              color: AppBrandGradients.accountMenuIconTint,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '100% Safe & Secure · No Hidden Charges · Verified Payments',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppBrandGradients.accountMenuIconTint,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
