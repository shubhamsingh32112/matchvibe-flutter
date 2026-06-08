import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/vip_benefits_content.dart';
import '../theme/vip_page_tokens.dart';
import 'vip_benefit_icon.dart';

class VipBenefitsDetailList extends StatelessWidget {
  const VipBenefitsDetailList({super.key, required this.sections});

  final List<VipBenefitSection> sections;

  static const double _iconSize = 62;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VipPageTokens.horizontalPadding,
      ),
      child: Column(
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            _BenefitDetailRow(section: sections[i], iconSize: _iconSize),
            if (i < sections.length - 1)
              Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.1),
              ),
          ],
        ],
      ),
    );
  }
}

class _BenefitDetailRow extends StatelessWidget {
  const _BenefitDetailRow({
    required this.section,
    required this.iconSize,
  });

  final VipBenefitSection section;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: VipBenefitIcon(
              assetPath: section.iconAsset,
              fallbackIcon: section.fallbackIcon,
              size: iconSize,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: GoogleFonts.lexend(
                    color: VipPageTokens.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  section.description,
                  style: GoogleFonts.lexend(
                    color: VipPageTokens.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
            ),
            child: const Icon(
              Icons.chevron_right_rounded,
              color: VipPageTokens.textMuted,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
