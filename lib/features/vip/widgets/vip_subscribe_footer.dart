import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/widgets/decorative_asset_image.dart';
import '../constants/vip_page_assets.dart';
import '../theme/vip_page_tokens.dart';

class VipSubscribeFooter extends StatelessWidget {
  const VipSubscribeFooter({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        VipPageTokens.horizontalPadding,
        8,
        VipPageTokens.horizontalPadding,
        12,
      ),
      color: VipPageTokens.pageBackgroundBottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 58,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: VipPageTokens.ctaGradient,
                borderRadius: BorderRadius.circular(29),
                boxShadow: [
                  BoxShadow(
                    color: VipPageTokens.borderGold.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isLoading ? null : onPressed,
                  borderRadius: BorderRadius.circular(29),
                  child: Center(
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF2A1060),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DecorativeAssetImage(
                                assetPath: VipPageAssets.crownSmall,
                                width: 45,
                                height: 45,
                                fallbackIcon: Icons.workspace_premium_rounded,
                                fallbackIconSize: 45,
                                fallbackIconColor: const Color(0xFF2A1060),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                label,
                                style: GoogleFonts.lexend(
                                  color: const Color(0xFF2A1060),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Cancel anytime • Auto-renewal can be turned off anytime',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VipPageTokens.textMuted.withValues(alpha: 0.85),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
