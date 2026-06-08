import 'package:flutter/material.dart';

import '../../../../shared/widgets/gem_icon.dart';
import '../../models/creator_task_model.dart';
import '../../theme/creator_home_tokens.dart';
import 'creator_task_ring.dart';

class CreatorTaskRow extends StatelessWidget {
  const CreatorTaskRow({
    super.key,
    required this.task,
    required this.totalMinutes,
  });

  final CreatorTask task;
  final double totalMinutes;

  @override
  Widget build(BuildContext context) {
    final progress = task.isCompleted
        ? task.thresholdMinutes.toDouble()
        : totalMinutes.clamp(0, task.thresholdMinutes.toDouble());
    final progressValue =
        (progress / task.thresholdMinutes).clamp(0.0, 1.0);
    final gradient = task.isCompleted
        ? CreatorHomeTokens.taskCompletedGradient
        : CreatorHomeTokens.taskInProgressGradient;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CreatorTaskRing(
            thresholdMinutes: task.thresholdMinutes,
            progress: progress.toDouble(),
            isCompleted: task.isCompleted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${task.thresholdMinutes} Minutes Completed',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'Talk time',
                  style: TextStyle(
                    fontSize: 11,
                    color: CreatorHomeTokens.labelGrey,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: CreatorHomeTokens.bannerLavender),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progressValue,
                          child: DecoratedBox(
                            decoration: BoxDecoration(gradient: gradient),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GemIcon(size: 14),
                  const SizedBox(width: 2),
                  Text(
                    '${task.rewardCoins}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Text(
                'Coins Earned',
                style: TextStyle(
                  fontSize: 10,
                  color: CreatorHomeTokens.labelGrey,
                ),
              ),
              const SizedBox(height: 4),
              _StatusPill(task: task, totalMinutes: totalMinutes),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.task, required this.totalMinutes});

  final CreatorTask task;
  final double totalMinutes;

  @override
  Widget build(BuildContext context) {
    if (task.isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: CreatorHomeTokens.completedGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Completed',
          style: TextStyle(
            color: CreatorHomeTokens.completedGreen,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final shown = totalMinutes.clamp(0, task.thresholdMinutes.toDouble());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: CreatorHomeTokens.primaryPurple.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${shown.toStringAsFixed(0)} / ${task.thresholdMinutes} min',
        style: const TextStyle(
          color: CreatorHomeTokens.primaryPurple,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
