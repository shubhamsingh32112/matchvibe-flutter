import 'package:flutter/material.dart';

import '../../account/theme/moments_premium_page_tokens.dart';

/// Crown + VIP pill for highlighted VIP comments.
class VipHighlightBadge extends StatelessWidget {
  const VipHighlightBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 6,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: MomentsPremiumPageTokens.accentPurple.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: MomentsPremiumPageTokens.accentPurple.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: compact ? 10 : 11,
            color: MomentsPremiumPageTokens.accentGold,
          ),
          const SizedBox(width: 3),
          Text(
            'VIP',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
