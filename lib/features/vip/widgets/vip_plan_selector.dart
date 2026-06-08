import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/vip_models.dart';
import '../theme/vip_page_tokens.dart';

class VipPlanSelector extends StatelessWidget {
  const VipPlanSelector({
    super.key,
    required this.plans,
    required this.selectedPlanId,
    required this.onPlanSelected,
  });

  final List<VipPlanOption> plans;
  final String selectedPlanId;
  final ValueChanged<String> onPlanSelected;

  static const double _cardHeight = 112;

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) return const SizedBox.shrink();

    final sortedPlans = [...plans]
      ..sort((a, b) => a.durationDays.compareTo(b.durationDays));

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VipPageTokens.horizontalPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < sortedPlans.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: _cardHeight,
                child: _PlanCard(
                  plan: sortedPlans[i],
                  selected: sortedPlans[i].planId == selectedPlanId,
                  onTap: () => onPlanSelected(sortedPlans[i].planId),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final VipPlanOption plan;
  final bool selected;
  final VoidCallback onTap;

  bool get _isMonthly => plan.durationDays <= 31;

  String _formatPrice(int value) {
    if (value >= 1000) {
      final text = value.toString();
      return '₹${text.substring(0, text.length - 3)},${text.substring(text.length - 3)}';
    }
    return '₹$value';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VipPageTokens.cardRadius),
        child: Ink(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: VipPageTokens.cardGradient,
            borderRadius: BorderRadius.circular(VipPageTokens.cardRadius),
            border: Border.all(
              color: selected
                  ? VipPageTokens.borderGold
                  : Colors.white.withValues(alpha: 0.12),
              width: selected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(11, 10, 11, 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: _SelectionIndicator(selected: selected),
              ),
              if (plan.badge == VipPlanBadge.bestValue)
                const Positioned(
                  top: -8,
                  left: 0,
                  child: _PlanBadge(label: 'Best Value', pink: true),
                ),
              if (plan.badge == VipPlanBadge.mostPopular)
                const Positioned(
                  top: -8,
                  left: 0,
                  child: _PlanBadge(label: 'Most Popular', pink: false),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    plan.label,
                    style: GoogleFonts.lexend(
                      color: VipPageTokens.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _PriceBlock(
                    plan: plan,
                    isMonthly: _isMonthly,
                    formatPrice: _formatPrice,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({
    required this.plan,
    required this.isMonthly,
    required this.formatPrice,
  });

  final VipPlanOption plan;
  final bool isMonthly;
  final String Function(int value) formatPrice;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isMonthly)
          _MonthlyPriceLine(price: plan.priceInr)
        else
          Text(
            formatPrice(plan.priceInr),
            style: GoogleFonts.lexend(
              color: VipPageTokens.textGold,
              fontWeight: FontWeight.w800,
              fontSize: 21,
              height: 1.05,
            ),
          ),
        SizedBox(height: isMonthly ? 0 : 3),
        if (!isMonthly)
          Text(
            '${formatPrice(plan.monthlyEquivalentInr)} / month',
            style: GoogleFonts.lexend(
              color: VipPageTokens.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w400,
              height: 1.15,
            ),
          ),
        if (plan.savingsLabel != null) ...[
          const SizedBox(height: 3),
          Text(
            plan.savingsLabel!,
            style: GoogleFonts.lexend(
              color: VipPageTokens.accentPink,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              height: 1.15,
            ),
          ),
        ],
      ],
    );
  }
}

class _MonthlyPriceLine extends StatelessWidget {
  const _MonthlyPriceLine({required this.price});

  final int price;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '₹$price',
            style: GoogleFonts.lexend(
              color: VipPageTokens.textGold,
              fontWeight: FontWeight.w800,
              fontSize: 21,
              height: 1.05,
            ),
          ),
          TextSpan(
            text: ' / month',
            style: GoogleFonts.lexend(
              color: VipPageTokens.textMuted,
              fontWeight: FontWeight.w400,
              fontSize: 11,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.label, required this.pink});

  final String label;
  final bool pink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: pink ? VipPageTokens.accentPink : null,
        gradient: pink ? null : VipPageTokens.goldBadgeGradient,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: GoogleFonts.lexend(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 8,
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          color: VipPageTokens.borderGold,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 13,
          color: Color(0xFF1A0D33),
        ),
      );
    }

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: VipPageTokens.textMuted.withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
    );
  }
}
