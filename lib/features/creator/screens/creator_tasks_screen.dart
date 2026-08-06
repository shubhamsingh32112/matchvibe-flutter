import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/creator_dashboard_provider.dart';
import '../providers/creator_task_provider.dart';
import '../models/creator_task_model.dart';
import '../utils/creator_earnings_display.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../../../shared/widgets/loading_indicator.dart';

class CreatorTasksScreen extends ConsumerStatefulWidget {
  const CreatorTasksScreen({super.key});

  @override
  ConsumerState<CreatorTasksScreen> createState() => _CreatorTasksScreenState();
}

class _CreatorTasksScreenState extends ConsumerState<CreatorTasksScreen> {
  final Set<String> _claimingTaskKeys = {};

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider.select((s) => s.user));

    if (user?.role != 'creator' && user?.role != 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
      });
      return const Scaffold(body: Center(child: Text('Unauthorized')));
    }

    final coins = user?.coins ?? 0;
    final tasksAsync = ref.watch(dashboardTasksProvider);

    return Scaffold(
      backgroundColor: AppBrandGradients.accountMenuPageBackground,
      appBar: buildAccountFlowAppBar(
        context,
        title: 'Weekly Targets',
        actions: [BrandHeaderCoinsChip(coins: coins)],
      ),
      body: tasksAsync.when(
        data: (tasksResponse) {
          return _TasksContent(
            tasksResponse: tasksResponse,
            claimingTaskKeys: _claimingTaskKeys,
            onClaim: (taskKey) => _claimTask(taskKey),
          );
        },
        loading: () => const Center(child: LoadingIndicator()),
        error: (error, stack) => _ErrorView(
          error: UserMessageMapper.userMessageFor(
            error,
            fallback: 'Couldn\'t load targets. Please try again.',
          ),
          onRetry: () => ref.invalidate(creatorDashboardProvider),
        ),
      ),
    );
  }

  Future<void> _claimTask(String taskKey) async {
    setState(() {
      _claimingTaskKeys.add(taskKey);
    });

    try {
      await ref.read(creatorTaskServiceProvider).claimTaskReward(taskKey);
      ref.invalidate(creatorDashboardProvider);

      if (mounted) {
        setState(() {
          _claimingTaskKeys.remove(taskKey);
        });
        AppToast.showSuccess(context, 'Reward claimed successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _claimingTaskKeys.remove(taskKey);
        });

        AppToast.showError(
          context,
          UserMessageMapper.userMessageFor(
            e,
            fallback: 'Couldn\'t claim reward. Please try again.',
          ),
        );
      }
    }
  }
}

class _TasksContent extends StatelessWidget {
  final CreatorTasksResponse tasksResponse;
  final Set<String> claimingTaskKeys;
  final Function(String) onClaim;

  const _TasksContent({
    required this.tasksResponse,
    required this.claimingTaskKeys,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalPaidCoins = tasksResponse.totalPaidCoins;
    final maxThreshold = tasksResponse.tasks.isEmpty
        ? 1.0
        : tasksResponse.tasks
            .map((t) => t.thresholdPaidCoins.toDouble())
            .reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "This Week's Paid Coins",
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppBrandGradients.walletCoinGold,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        CreatorEarningsDisplay.formatCoins(totalPaidCoins),
                        style: const TextStyle(
                          color: AppBrandGradients.walletOnGold,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => context.push('/creator/withdraw'),
                      child: const Text('Withdraw'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _NextTargetPreview(
                  totalPaidCoins: totalPaidCoins,
                  tasks: tasksResponse.tasks,
                ),
                const SizedBox(height: 8),
                Text(
                  'Targets reset weekly (every Monday). Earn paid-call coins to unlock bonuses!',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          AppCard(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progress',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (totalPaidCoins / maxThreshold).clamp(0.0, 1.0),
                    minHeight: 12,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final t in tasksResponse.tasks)
                      _MilestoneMarker(
                        label: '${(t.thresholdPaidCoins / 1000).round()}k',
                        threshold: t.thresholdPaidCoins,
                        currentPaidCoins: totalPaidCoins,
                      ),
                  ],
                ),
              ],
            ),
          ),

          if (tasksResponse.resetsAt != null)
            _WeeklyResetCountdown(resetsAt: tasksResponse.resetsAt!),

          Text(
            'Targets',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (tasksResponse.tasks.isEmpty)
            const _EmptyState()
          else
            ...tasksResponse.tasks.map(
              (task) => _TaskCard(
                task: task,
                isClaiming: claimingTaskKeys.contains(task.taskKey),
                onClaim: () => onClaim(task.taskKey),
              ),
            ),
        ],
      ),
    );
  }
}

class _MilestoneMarker extends StatelessWidget {
  final String label;
  final int threshold;
  final double currentPaidCoins;

  const _MilestoneMarker({
    required this.label,
    required this.threshold,
    required this.currentPaidCoins,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isReached = currentPaidCoins >= threshold;

    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isReached ? scheme.primary : scheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isReached
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: isReached ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends StatefulWidget {
  final CreatorTask task;
  final bool isClaiming;
  final VoidCallback onClaim;

  const _TaskCard({
    required this.task,
    required this.isClaiming,
    required this.onClaim,
  });

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _wasCompleted = false;

  @override
  void initState() {
    super.initState();
    _wasCompleted = widget.task.isCompleted;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    if (widget.task.isCompleted && !widget.task.isClaimed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animationController.forward();
      });
    }
  }

  @override
  void didUpdateWidget(_TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_wasCompleted && widget.task.isCompleted && !widget.task.isClaimed) {
      _animationController.forward();
      _wasCompleted = true;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final task = widget.task;
    final isClaiming = widget.isClaiming;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: task.isCompleted
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      boxShadow: task.isCompleted && !task.isClaimed
                          ? [
                              BoxShadow(
                                color: scheme.primary.withValues(
                                  alpha: 0.5 * _animationController.value,
                                ),
                                blurRadius: 8 * _animationController.value,
                                spreadRadius: 2 * _animationController.value,
                              ),
                            ]
                          : null,
                    ),
                    child: task.isCompleted
                        ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
                        : null,
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${CreatorEarningsDisplay.formatCoins(task.thresholdPaidCoins)} paid coins',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${CreatorEarningsDisplay.formatCoins(task.progressPaidCoins)} / ${CreatorEarningsDisplay.formatCoins(task.thresholdPaidCoins)} coins',
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: AppBrandGradients.walletCoinGold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${task.rewardCoins} coins',
                  style: const TextStyle(
                    color: AppBrandGradients.walletOnGold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: task.progressPercentage,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                task.isCompleted
                    ? scheme.primary
                    : scheme.primary.withValues(alpha: 0.5),
              ),
            ),
          ),
          if (task.canClaim) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isClaiming ? null : widget.onClaim,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  disabledBackgroundColor: scheme.surfaceContainerHighest,
                ),
                child: isClaiming
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            scheme.onPrimary,
                          ),
                        ),
                      )
                    : const Text('Claim Reward'),
              ),
            ),
          ],
          if (task.isClaimed) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 16, color: scheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Reward claimed',
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.phone_disabled_outlined,
      title: 'No paid-call earnings yet',
      message:
          'Complete paid video calls this week to progress toward your weekly coin targets.',
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ErrorState(
      title: 'Failed to load targets',
      message: error,
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}

class _NextTargetPreview extends StatelessWidget {
  final double totalPaidCoins;
  final List<CreatorTask> tasks;

  const _NextTargetPreview({
    required this.totalPaidCoins,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    try {
      final nextTask = tasks.firstWhere((task) => !task.isCompleted);
      final coinsNeeded = nextTask.thresholdPaidCoins - totalPaidCoins;

      if (coinsNeeded <= 0) {
        return const SizedBox.shrink();
      }

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.trending_up, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Next reward in ${CreatorEarningsDisplay.formatCoins(coinsNeeded)} paid coins (+${nextTask.rewardCoins} bonus)',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (_) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.celebration, size: 16, color: scheme.onPrimaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'All weekly targets completed!',
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}

class _WeeklyResetCountdown extends StatefulWidget {
  final DateTime resetsAt;

  const _WeeklyResetCountdown({required this.resetsAt});

  @override
  State<_WeeklyResetCountdown> createState() => _WeeklyResetCountdownState();
}

class _WeeklyResetCountdownState extends State<_WeeklyResetCountdown> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    final now = DateTime.now();
    final diff = widget.resetsAt.toLocal().difference(now);
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
  }

  @override
  void didUpdateWidget(_WeeklyResetCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetsAt != widget.resetsAt) {
      _updateRemaining();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = _remaining.inDays;
    final hours = _remaining.inHours.remainder(24);
    final minutes = _remaining.inMinutes.remainder(60);

    final timeText = days > 0
        ? '${days}d ${hours}h'
        : hours > 0
            ? '${hours}h ${minutes}m'
            : '${minutes}m';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.tertiary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 20, color: scheme.tertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Targets Reset',
                  style: TextStyle(
                    color: scheme.onTertiaryContainer,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Progress resets every Monday at midnight',
                  style: TextStyle(
                    color: scheme.onTertiaryContainer.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.tertiary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              timeText,
              style: TextStyle(
                color: scheme.tertiary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
