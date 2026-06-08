import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/vip_models.dart';
import '../theme/vip_page_tokens.dart';

class VipFeaturedPlanBanner extends StatelessWidget {
  const VipFeaturedPlanBanner({super.key, required this.plan});

  final VipPlanOption plan;

  @override
  Widget build(BuildContext context) {
    final billingNote = plan.durationDays >= 360
        ? 'Billed as ₹${plan.priceInr} every 12 months'
        : plan.durationDays >= 180
        ? 'Billed as ₹${plan.priceInr} every 6 months'
        : 'Billed as ₹${plan.priceInr} every ${plan.durationDays} days';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VipPageTokens.horizontalPadding,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            decoration: BoxDecoration(
              gradient: VipPageTokens.cardGradient,
              borderRadius: BorderRadius.circular(VipPageTokens.cardRadius),
              border: Border.all(color: VipPageTokens.borderGold, width: 1.5),
              boxShadow: VipPageTokens.cardShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹${plan.priceInr}',
                        style: GoogleFonts.lexend(
                          color: VipPageTokens.textGold,
                          fontWeight: FontWeight.w800,
                          fontSize: 28,
                        ),
                      ),
                      Text(
                        '/ ${plan.durationDays >= 360
                            ? '12 Months'
                            : plan.durationDays >= 180
                            ? '6 Months'
                            : plan.label}',
                        style: GoogleFonts.lexend(
                          color: VipPageTokens.textGold.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        billingNote,
                        style: const TextStyle(
                          color: VipPageTokens.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (plan.savingsLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: VipPageTokens.accentPink.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: VipPageTokens.accentPink.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      plan.savingsLabel!,
                      style: const TextStyle(
                        color: VipPageTokens.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (plan.badge == VipPlanBadge.mostPopular)
            Positioned(
              top: -10,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: VipPageTokens.goldBadgeGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Most Popular',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
