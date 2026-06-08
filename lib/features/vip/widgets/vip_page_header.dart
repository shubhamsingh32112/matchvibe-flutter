import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/widgets/decorative_asset_image.dart';
import '../constants/vip_page_assets.dart';
import '../theme/vip_page_tokens.dart';

class VipPageHeader extends StatelessWidget {
  const VipPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        VipPageTokens.horizontalPadding,
        topInset + 8,
        VipPageTokens.horizontalPadding,
        8,
      ),
      child: Row(
        children: [
          DecorativeAssetImage(
            assetPath: VipPageAssets.crownSmall,
            width: 28,
            height: 28,
            fallbackIcon: Icons.workspace_premium_rounded,
            fallbackIconColor: VipPageTokens.textGold,
          ),
          const SizedBox(width: 8),
          Text(
            'VIP',
            style: GoogleFonts.lexend(
              color: VipPageTokens.textGold,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VipPageTokens.pillRadius),
              border: Border.all(
                color: VipPageTokens.textGold.withValues(alpha: 0.55),
              ),
              color: Colors.white.withValues(alpha: 0.08),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 16,
                  color: VipPageTokens.textGold.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 6),
                Text(
                  'Secure Payment',
                  style: GoogleFonts.lexend(
                    color: VipPageTokens.textGold.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
