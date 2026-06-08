import 'package:flutter/material.dart';

import '../../theme/creator_home_tokens.dart';

class CreatorTaskRing extends StatelessWidget {
  const CreatorTaskRing({
    super.key,
    required this.thresholdMinutes,
    required this.progress,
    required this.isCompleted,
  });

  final int thresholdMinutes;
  final double progress;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    const ringSize = 72.0;
    const strokeWidth = 5.0;
    const innerPadding = strokeWidth + 6;
    final value = (progress / thresholdMinutes).clamp(0.0, 1.0);

    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: ringSize,
            height: ringSize,
            child: CircularProgressIndicator(
              value: isCompleted ? 1 : value,
              strokeWidth: strokeWidth,
              backgroundColor: CreatorHomeTokens.bannerLavender,
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted
                    ? CreatorHomeTokens.pinkAccent
                    : CreatorHomeTokens.primaryPurple,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(innerPadding),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$thresholdMinutes',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  const Text(
                    'min',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                      color: CreatorHomeTokens.labelGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
