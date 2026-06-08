import 'package:flutter/material.dart';
import '../../../shared/styles/app_brand_styles.dart';

class VipBadge extends StatelessWidget {
  final bool compact;

  const VipBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        gradient: AppBrandGradients.vipBadgeGradient,
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        boxShadow: [
          BoxShadow(
            color: AppBrandGradients.vipBadgeGold.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: compact ? 12 : 14,
            color: Colors.white,
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            'VIP',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
