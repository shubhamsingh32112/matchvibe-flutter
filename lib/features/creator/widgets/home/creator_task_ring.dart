import 'package:flutter/material.dart';

import '../../theme/creator_home_tokens.dart';

class CreatorTaskRing extends StatelessWidget {
  const CreatorTaskRing({
    super.key,
    required this.thresholdPaidCoins,
    required this.progress,
    required this.isCompleted,
  });

  final int thresholdPaidCoins;
  final double progress;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final value = thresholdPaidCoins == 0
        ? 0.0
        : (progress / thresholdPaidCoins).clamp(0.0, 1.0);
    final gradient = isCompleted
        ? CreatorHomeTokens.taskCompletedGradient
        : CreatorHomeTokens.taskInProgressGradient;

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 4,
              backgroundColor: CreatorHomeTokens.bannerLavender,
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted
                    ? CreatorHomeTokens.pinkAccentDeep
                    : CreatorHomeTokens.primaryPurple,
              ),
            ),
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => gradient.createShader(bounds),
            child: Text(
              thresholdPaidCoins >= 1000
                  ? '${(thresholdPaidCoins / 1000).round()}k'
                  : '$thresholdPaidCoins',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
