import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/widgets/decorative_asset_image.dart';
import '../constants/vip_benefits_content.dart';
import '../constants/vip_page_assets.dart';
import '../theme/vip_page_tokens.dart';

class VipHeroSection extends StatelessWidget {
  const VipHeroSection({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VipPageTokens.horizontalPadding,
      ),
      child: compact ? _buildCompactHero() : _buildHeroRow(),
    );
  }

  Widget _buildCompactHero() {
    return Column(
      children: [
        _CompactCrown(),
        const SizedBox(height: 12),
        Text(
          'VIP Active',
          textAlign: TextAlign.center,
          style: GoogleFonts.lexend(
            color: VipPageTokens.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 24,
            height: 1.15,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enjoy your premium perks every day.',
          textAlign: TextAlign.center,
          style: GoogleFonts.lexend(
            color: VipPageTokens.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const _CrownShowcase(),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Go VIP, Get More',
                style: GoogleFonts.lexend(
                  color: VipPageTokens.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                  height: 1.15,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'More connections, more rewards, more you.',
                style: GoogleFonts.lexend(
                  color: VipPageTokens.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              const _SocialProofRow(alignStart: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _CrownShowcase extends StatelessWidget {
  const _CrownShowcase();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 195,
      child: Stack(
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -28,
            top: -8,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withValues(alpha: 0.38),
                    VipPageTokens.pageBackgroundTop.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          DecorativeAssetImage(
            assetPath: VipPageAssets.crownHero,
            width: 196,
            height: 131,
            alignment: Alignment.centerLeft,
            fallbackIcon: Icons.workspace_premium_rounded,
            fallbackIconSize: 96,
            fallbackIconColor: VipPageTokens.textGold,
          ),
        ],
      ),
    );
  }
}

class _CompactCrown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecorativeAssetImage(
      assetPath: VipPageAssets.crownHero,
      width: 96,
      height: 64,
      fallbackIcon: Icons.workspace_premium_rounded,
      fallbackIconSize: 72,
      fallbackIconColor: VipPageTokens.textGold,
    );
  }
}

class _SocialProofRow extends StatelessWidget {
  const _SocialProofRow({this.alignStart = false});

  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          alignStart ? MainAxisAlignment.start : MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 72,
          height: 28,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _avatar(0),
              Positioned(left: 18, child: _avatar(1)),
              Positioned(left: 36, child: _avatar(2)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '${_formatCount(vipSocialProofMemberCount)}+ Happy VIP Members',
            style: GoogleFonts.lexend(
              color: VipPageTokens.textGold,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatar(int index) {
    final colors = [
      const Color(0xFFFF8F00),
      const Color(0xFFAB47BC),
      const Color(0xFF42A5F5),
    ];
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors[index % colors.length],
        border: Border.all(color: VipPageTokens.pageBackgroundTop, width: 2),
      ),
      child: Icon(
        Icons.person,
        size: 16,
        color: Colors.white.withValues(alpha: 0.95),
      ),
    );
  }

  String _formatCount(int value) {
    if (value >= 1000) {
      final thousands = value / 1000;
      if (value % 1000 == 0) return '${thousands.toInt()}K';
      return '${thousands.toStringAsFixed(1)}K';
    }
    return '$value';
  }
}
