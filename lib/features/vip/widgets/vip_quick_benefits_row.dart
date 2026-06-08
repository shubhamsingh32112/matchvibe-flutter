import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/vip_benefits_content.dart';
import '../theme/vip_page_tokens.dart';
import 'vip_benefit_icon.dart';

class VipQuickBenefitsRow extends StatelessWidget {
  const VipQuickBenefitsRow({super.key, required this.sections});

  final List<VipBenefitSection> sections;

  static const double _iconSize = 52;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VipPageTokens.horizontalPadding,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(VipPageTokens.cardRadius),
          border: Border.all(
            color: const Color(0xFF9C6ADE).withValues(alpha: 0.28),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < sections.length; i++) ...[
                if (i > 0) const _BenefitDivider(),
                Expanded(child: _QuickBenefitTile(section: sections[i])),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitDivider extends StatelessWidget {
  const _BenefitDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        width: 1,
        color: Colors.white.withValues(alpha: 0.14),
      ),
    );
  }
}

class _QuickBenefitTile extends StatelessWidget {
  const _QuickBenefitTile({required this.section});

  final VipBenefitSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: VipQuickBenefitsRow._iconSize,
            height: VipQuickBenefitsRow._iconSize,
            child: VipBenefitIcon(
              assetPath: section.iconAsset,
              fallbackIcon: section.fallbackIcon,
              size: VipQuickBenefitsRow._iconSize,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            section.shortTitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lexend(
              color: VipPageTokens.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            section.shortDescription,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lexend(
              color: VipPageTokens.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w400,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
