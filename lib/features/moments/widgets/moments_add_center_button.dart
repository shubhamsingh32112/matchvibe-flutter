import 'package:flutter/material.dart';

import '../../../shared/styles/app_brand_styles.dart';
import 'moments_assets.dart';

/// Floating bottom-centre control for creators to post a reel (video moment).
class MomentsPostReelFab extends StatelessWidget {
  const MomentsPostReelFab({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  static const double size = 64;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Post reel',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Image.asset(
            MomentsAssets.postReelFabIcon,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: Color(0xFF9B4DFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 32),
            ),
          ),
        ),
      ),
    );
  }
}

class MomentsFeedEmptyState extends StatelessWidget {
  const MomentsFeedEmptyState({
    super.key,
    this.onAddMoment,
    this.message = 'No moments yet',
  });

  final VoidCallback? onAddMoment;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          onAddMoment != null ? '$message\nTap + below to post a moment' : message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppBrandGradients.momentsTabInactiveColor,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
