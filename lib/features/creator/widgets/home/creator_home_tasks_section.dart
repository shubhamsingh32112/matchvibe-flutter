import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/user_message_mapper.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/gem_icon.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../constants/creator_home_assets.dart';
import '../../models/creator_task_model.dart';
import '../../providers/creator_dashboard_provider.dart';
import '../../providers/creator_task_provider.dart';
import '../../theme/creator_home_tokens.dart';
import '../../utils/creator_earnings_display.dart';

enum _TargetStatus { completed, inProgress, locked }

class CreatorHomeTasksSection extends ConsumerStatefulWidget {
  const CreatorHomeTasksSection({super.key});

  @override
  ConsumerState<CreatorHomeTasksSection> createState() =>
      _CreatorHomeTasksSectionState();
}

class _CreatorHomeTasksSectionState
    extends ConsumerState<CreatorHomeTasksSection> {
  final Set<String> _claimingKeys = {};

  Future<void> _claim(String taskKey) async {
    setState(() => _claimingKeys.add(taskKey));
    try {
      await ref.read(creatorTaskServiceProvider).claimTaskReward(taskKey);
      ref.invalidate(creatorDashboardProvider);
      if (mounted) {
        AppToast.showSuccess(context, 'Reward claimed successfully!');
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          UserMessageMapper.userMessageFor(
            e,
            fallback: 'Couldn\'t claim reward. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _claimingKeys.remove(taskKey));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(dashboardTasksProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: CreatorHomeTokens.sectionSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Image.asset(
                CreatorHomeAssets.tasksReward,
                width: 40,
                height: 40,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.flag_rounded,
                  color: CreatorHomeTokens.pinkAccent,
                  size: 40,
                ),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Weekly Targets',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: CreatorHomeTokens.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/creator/tasks'),
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: CreatorHomeTokens.primaryPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          tasksAsync.when(
            data: (tasksResponse) {
              final resetsLabel = CreatorEarningsDisplay.resetsInLabel(
                tasksResponse.resetsAt,
              );
              final tasks = tasksResponse.tasks;
              final firstIncompleteIndex =
                  tasks.indexWhere((t) => !t.isCompleted);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: CreatorHomeTokens.cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (resetsLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: CreatorHomeTokens.primaryPurple,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              resetsLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: CreatorHomeTokens.primaryPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ...List.generate(tasks.length, (index) {
                      final task = tasks[index];
                      final status = _statusFor(
                        task: task,
                        index: index,
                        firstIncompleteIndex: firstIncompleteIndex,
                      );
                      return _WeeklyTargetRow(
                        task: task,
                        status: status,
                        currentPaidCoins: tasksResponse.totalPaidCoins,
                        claiming: _claimingKeys.contains(task.taskKey),
                        onClaim: () => _claim(task.taskKey),
                      );
                    }),
                  ],
                ),
              );
            },
            loading: () => Container(
              height: 160,
              decoration: CreatorHomeTokens.cardDecoration(),
              child: const Center(child: LoadingIndicator()),
            ),
            error: (_, __) => Container(
              padding: const EdgeInsets.all(16),
              decoration: CreatorHomeTokens.cardDecoration(),
              child: TextButton(
                onPressed: () => ref.invalidate(creatorDashboardProvider),
                child: const Text('Retry loading targets'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _TargetStatus _statusFor({
    required CreatorTask task,
    required int index,
    required int firstIncompleteIndex,
  }) {
    if (task.isCompleted) return _TargetStatus.completed;
    if (firstIncompleteIndex < 0 || index == firstIncompleteIndex) {
      return _TargetStatus.inProgress;
    }
    if (index > firstIncompleteIndex) return _TargetStatus.locked;
    return _TargetStatus.inProgress;
  }
}

class _WeeklyTargetRow extends StatelessWidget {
  const _WeeklyTargetRow({
    required this.task,
    required this.status,
    required this.currentPaidCoins,
    required this.claiming,
    required this.onClaim,
  });

  final CreatorTask task;
  final _TargetStatus status;
  final double currentPaidCoins;
  final bool claiming;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final progressValue = task.progressPercentage;
    final shown = currentPaidCoins
        .clamp(0, task.thresholdPaidCoins.toDouble())
        .toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusDot(status: status),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const GemIcon(size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${CreatorEarningsDisplay.formatCoins(task.thresholdPaidCoins)} Coins',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: CreatorHomeTokens.textPrimary,
                        ),
                      ),
                    ),
                    _StatusBadge(status: status, isClaimed: task.isClaimed),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  CreatorEarningsDisplay.formatInr(task.thresholdPaidCoins),
                  style: const TextStyle(
                    fontSize: 11,
                    color: CreatorHomeTokens.labelGrey,
                  ),
                ),
                if (status != _TargetStatus.completed) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 5,
                      backgroundColor: CreatorHomeTokens.bannerLavender,
                      color: status == _TargetStatus.locked
                          ? CreatorHomeTokens.labelGrey
                          : CreatorHomeTokens.primaryPurple,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$shown / ${task.thresholdPaidCoins}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: CreatorHomeTokens.labelGrey,
                    ),
                  ),
                ],
                if (task.canClaim) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: claiming ? null : onClaim,
                      style: TextButton.styleFrom(
                        backgroundColor: CreatorHomeTokens.pinkAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: claiming
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Claim +${task.rewardCoins}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final _TargetStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _TargetStatus.completed:
        return Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: CreatorHomeTokens.completedGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 16),
        );
      case _TargetStatus.inProgress:
        return Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: CreatorHomeTokens.primaryPurple,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.groups, color: Colors.white, size: 16),
        );
      case _TargetStatus.locked:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: CreatorHomeTokens.labelGrey.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_outline, color: Colors.white, size: 14),
        );
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.isClaimed});

  final _TargetStatus status;
  final bool isClaimed;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    switch (status) {
      case _TargetStatus.completed:
        label = isClaimed ? 'Claimed' : 'Completed';
        color = CreatorHomeTokens.completedGreen;
      case _TargetStatus.inProgress:
        label = 'In Progress';
        color = CreatorHomeTokens.primaryPurple;
      case _TargetStatus.locked:
        label = 'Locked';
        color = CreatorHomeTokens.labelGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
