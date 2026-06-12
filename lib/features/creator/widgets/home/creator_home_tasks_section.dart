import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants/creator_home_assets.dart';
import '../../providers/creator_dashboard_provider.dart';
import '../../theme/creator_home_tokens.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../video/providers/call_billing_provider.dart';
import 'creator_task_row.dart';

/// Effective talk-time minutes for task UI, including optimistic in-call progress.
double creatorHomeEffectiveTaskMinutes(WidgetRef ref, double baseMinutes) {
  final billing = ref.watch(callBillingProvider);
  if (!billing.isActive) return baseMinutes;
  final extra = billing.elapsedSeconds / 60.0;
  return baseMinutes + extra;
}

class CreatorHomeTasksSection extends ConsumerWidget {
  const CreatorHomeTasksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                width: 48,
                height: 48,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.card_giftcard,
                  color: CreatorHomeTokens.pinkAccent,
                  size: 48,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tasks & Rewards',
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
                  'View all tasks',
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
              final totalMinutes = creatorHomeEffectiveTaskMinutes(
                ref,
                tasksResponse.totalMinutes,
              );
              final visibleTasks = tasksResponse.tasks.take(2).toList();

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: CreatorHomeTokens.cardDecoration(),
                child: Column(
                  children: visibleTasks
                      .map(
                        (task) => CreatorTaskRow(
                          task: task,
                          totalMinutes: totalMinutes,
                        ),
                      )
                      .toList(),
                ),
              );
            },
            loading: () => Container(
              height: 140,
              decoration: CreatorHomeTokens.cardDecoration(),
              child: const Center(child: LoadingIndicator()),
            ),
            error: (_, __) => Container(
              padding: const EdgeInsets.all(16),
              decoration: CreatorHomeTokens.cardDecoration(),
              child: TextButton(
                onPressed: () => ref.invalidate(creatorDashboardProvider),
                child: const Text('Retry loading tasks'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
