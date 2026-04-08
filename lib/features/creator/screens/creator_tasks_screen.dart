import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/creator_dashboard_provider.dart';
import '../providers/creator_task_provider.dart';
import '../models/creator_task_model.dart';
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
  // Track claiming state for optimistic UX
  final Set<String> _claimingTaskKeys = {};

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (user?.creatorApplicationPending == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/agent-verification');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 🔒 PHASE T2: Role guard at route level
    if (user?.role != 'creator' && user?.role != 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
      });
      return const Scaffold(body: Center(child: Text('Unauthorized')));
    }
    
    final coins = user?.coins ?? 0;
    // Use dashboard-derived tasks provider (auto-synced via socket)
    final tasksAsync = ref.watch(dashboardTasksProvider);

    return Scaffold(
      backgroundColor: AppBrandGradients.accountMenuPageBackground,
      appBar: buildBrandAppBar(
        context,
        title: 'Tasks & Rewards',
        actions: [BrandHeaderCoinsChip(coins: coins)],
      ),
      body: tasksAsync.when(
        data: (tasksResponse) {
          if (tasksResponse.totalMinutes == 0) {
            return _EmptyState();
          }
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
            fallback: 'Couldn\'t load tasks. Please try again.',
          ),
          onRetry: () => ref.invalidate(creatorDashboardProvider),
        ),
      ),
    );
  }

  // 🔒 PHASE T2: Optimistic claim UX (without coin mutation)
  Future<void> _claimTask(String taskKey) async {
    // Optimistically disable button and show spinner
    setState(() {
      _claimingTaskKeys.add(taskKey);
    });

    try {
      await ref.read(creatorTaskServiceProvider).claimTaskReward(taskKey);
      
      // Invalidate dashboard to refresh task state (mark as claimed)
      // The backend also emits creator:data_updated, but invalidate immediately for responsiveness
      ref.invalidate(creatorDashboardProvider);
      
      // Remove from claiming set
      if (mounted) {
        setState(() {
          _claimingTaskKeys.remove(taskKey);
        });
      }
      
      // DO NOT modify coins locally - wait for coins_updated socket event
      // This matches wallet & call billing behavior
      
      if (mounted) {
        AppToast.showSuccess(context, 'Reward claimed successfully!');
      }
    } catch (e) {
      // Remove from claiming set on error
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
    final totalMinutes = tasksResponse.totalMinutes;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Card: Total Minutes Completed
          AppCard(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Minutes",
                  style: TextStyle(
                    color: scheme.onSurface.withOpacity(0.7),
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
                        '${totalMinutes.toStringAsFixed(1)} mins',
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
                // B) Next task preview - "Next reward in X minutes"
                _NextTaskPreview(
                  totalMinutes: totalMinutes,
                  tasks: tasksResponse.tasks,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tasks reset daily at 11:59 PM. Complete calls to earn bonus coins!',
                  style: TextStyle(
                    color: scheme.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Progress Slider
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
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (totalMinutes / 600).clamp(0.0, 1.0), // Max 600 mins (4 hours)
                    minHeight: 12,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Milestones
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MilestoneMarker(
                      label: '1hr',
                      minutes: 60,
                      currentMinutes: totalMinutes,
                    ),
                    _MilestoneMarker(
                      label: '2hrs',
                      minutes: 120,
                      currentMinutes: totalMinutes,
                    ),
                    _MilestoneMarker(
                      label: '3hrs',
                      minutes: 180,
                      currentMinutes: totalMinutes,
                    ),
                    _MilestoneMarker(
                      label: '4hrs',
                      minutes: 240,
                      currentMinutes: totalMinutes,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Daily Reset Countdown
          if (tasksResponse.resetsAt != null)
            _DailyResetCountdown(resetsAt: tasksResponse.resetsAt!),

          // Task List
          Text(
            'Tasks',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...tasksResponse.tasks.map((task) => _TaskCard(
                task: task,
                isClaiming: claimingTaskKeys.contains(task.taskKey),
                onClaim: () => onClaim(task.taskKey),
              )),
        ],
      ),
    );
  }
}

class _MilestoneMarker extends StatelessWidget {
  final String label;
  final int minutes;
  final double currentMinutes;

  const _MilestoneMarker({
    required this.label,
    required this.minutes,
    required this.currentMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isReached = currentMinutes >= minutes;

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
                : scheme.onSurface.withOpacity(0.5),
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

class _TaskCardState extends State<_TaskCard> with SingleTickerProviderStateMixin {
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
    
    // 🔒 PHASE T4: Visual "completion moment" - animate when task becomes completed
    if (widget.task.isCompleted && !widget.task.isClaimed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animationController.forward();
      });
    }
  }

  @override
  void didUpdateWidget(_TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animate when task transitions from incomplete to completed
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
          // Task header
          Row(
            children: [
              // Checkbox/checkmark with animation
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
                                color: scheme.primary.withOpacity(
                                  0.5 * _animationController.value,
                                ),
                                blurRadius: 8 * _animationController.value,
                                spreadRadius: 2 * _animationController.value,
                              ),
                            ]
                          : null,
                    ),
                    child: task.isCompleted
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: scheme.onPrimary,
                          )
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
                      'Complete ${task.thresholdMinutes} minutes',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${task.progressMinutes.toStringAsFixed(1)} / ${task.thresholdMinutes} minutes',
                      style: TextStyle(
                        color: scheme.onSurface.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Reward label
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

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: task.progressPercentage,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                task.isCompleted ? scheme.primary : scheme.primary.withOpacity(0.5),
              ),
            ),
          ),

          // Claim button
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
                          valueColor: AlwaysStoppedAnimation<Color>(scheme.onPrimary),
                        ),
                      )
                    : const Text('Claim Reward'),
              ),
            ),
          ],

          // Claimed indicator
          if (task.isClaimed) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: scheme.primary,
                ),
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

// 🔒 PHASE T2: Empty state - "No completed calls yet" (NOT "No tasks")
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.phone_disabled_outlined,
      title: 'No completed calls yet',
      message: 'Complete video calls to start earning bonus coins! Your progress will appear here once you finish your first call.',
    );
  }
}

// 🔒 PHASE T2: Error state (explicit)
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorState(
      title: 'Failed to load tasks',
      message: error,
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}

// B) Next task preview - Pure UX sugar
class _NextTaskPreview extends StatelessWidget {
  final double totalMinutes;
  final List<CreatorTask> tasks;

  const _NextTaskPreview({
    required this.totalMinutes,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    // Find next uncompleted task
    try {
      final nextTask = tasks.firstWhere((task) => !task.isCompleted);
      final minutesNeeded = nextTask.thresholdMinutes - totalMinutes;
      
      if (minutesNeeded <= 0) {
        return const SizedBox.shrink();
      }

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: scheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.trending_up,
              size: 16,
              color: scheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Next reward in ${minutesNeeded.toStringAsFixed(0)} minutes (+${nextTask.rewardCoins} coins)',
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
    } catch (e) {
      // All tasks completed
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.celebration,
              size: 16,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'All tasks completed! 🎉',
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

/// Live countdown showing time remaining until the daily task reset.
class _DailyResetCountdown extends StatefulWidget {
  final DateTime resetsAt;

  const _DailyResetCountdown({required this.resetsAt});

  @override
  State<_DailyResetCountdown> createState() => _DailyResetCountdownState();
}

class _DailyResetCountdownState extends State<_DailyResetCountdown> {
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
  void didUpdateWidget(_DailyResetCountdown oldWidget) {
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
    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes.remainder(60);
    final seconds = _remaining.inSeconds.remainder(60);

    final timeText = hours > 0
        ? '${hours}h ${minutes}m ${seconds}s'
        : minutes > 0
            ? '${minutes}m ${seconds}s'
            : '${seconds}s';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.tertiary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            size: 20,
            color: scheme.tertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Tasks Reset',
                  style: TextStyle(
                    color: scheme.onTertiaryContainer,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Progress resets daily at 11:59 PM',
                  style: TextStyle(
                    color: scheme.onTertiaryContainer.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.tertiary.withOpacity(0.15),
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
