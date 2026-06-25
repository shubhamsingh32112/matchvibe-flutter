import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/brand_app_chrome.dart';
import '../../account/theme/moments_premium_page_tokens.dart';
import '../providers/moments_providers.dart';
import '../utils/moments_paywall.dart';

class MomentsHeader {
  MomentsHeader._();

  static AppBar appBar(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(momentsCapabilitiesProvider);

    return buildBrandAppBar(
      context,
      title: 'Moments ✨',
      actions: [
        if (capabilities.showPremiumButton)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () => showMomentsPremiumSheet(context, ref, source: 'header'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                backgroundColor: Colors.black.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: MomentsPremiumPageTokens.accentPurple.withValues(alpha: 0.8),
                  ),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.workspace_premium,
                    size: 16,
                    color: MomentsPremiumPageTokens.accentGold,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Premium',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
