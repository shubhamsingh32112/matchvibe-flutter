import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_modal_bottom_sheet.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../telegram_reward/widgets/telegram_reward_sheet.dart';
import '../models/rewards_hub_models.dart';
import '../providers/rewards_hub_provider.dart';

class RewardsHubScreen extends ConsumerStatefulWidget {
  const RewardsHubScreen({super.key});

  @override
  ConsumerState<RewardsHubScreen> createState() => _RewardsHubScreenState();
}

class _RewardsHubScreenState extends ConsumerState<RewardsHubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rewardsHubProvider.notifier).load();
    });
  }

  Future<void> _onTaskTap(RewardsHubTask task) async {
    if (task.key == 'telegram_join') {
      await showAppModalBottomSheet<void>(
        context: context,
        builder: (_) => const TelegramRewardSheet(),
      );
      if (mounted) {
        await ref.read(rewardsHubProvider.notifier).load(silent: true);
      }
      return;
    }

    if (task.claimable) {
      try {
        final result =
            await ref.read(rewardsHubProvider.notifier).claim(task.key);
        if (!mounted) return;
        if (result.coinsCredited > 0) {
          AppToast.showSuccess(
            context,
            'Congratulations!\n${result.coinsCredited} Coins have been added.',
          );
        } else if (result.alreadyClaimed) {
          AppToast.showSuccess(context, 'Already claimed.');
        }
      } catch (e) {
        if (mounted) {
          AppToast.showError(context, e.toString());
        }
      }
      return;
    }

    if (task.ctaType == 'route' && task.ctaValue.isNotEmpty) {
      context.push(task.ctaValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(rewardsHubProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0E0F14),
      appBar: AppBar(
        title: const Text('Rewards'),
        backgroundColor: const Color(0xFF0E0F14),
        foregroundColor: Colors.white,
      ),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF229ED9)),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                e.toString(),
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.read(rewardsHubProvider.notifier).load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          if (data == null || !data.enabled) {
            return const Center(
              child: Text(
                'Rewards are not available right now.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(rewardsHubProvider.notifier).load(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: data.tasks.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Complete tasks to earn free coins. Balance: ${data.coinsBalance}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13,
                      ),
                    ),
                  );
                }
                final task = data.tasks[index - 1];
                return _TaskCard(task: task, onTap: () => _onTaskTap(task));
              },
            ),
          );
        },
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onTap});

  final RewardsHubTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final claimed = task.claimed || task.status == 'claimed';
    final progress = task.progressTarget != null && task.progressTarget! > 0
        ? (task.progressCurrent ?? 0) / task.progressTarget!
        : null;

    return Material(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: claimed && !task.claimable ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF229ED9).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+${task.coins}',
                      style: const TextStyle(
                        color: Color(0xFF229ED9),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                task.description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    color: const Color(0xFF229ED9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${task.progressCurrent ?? 0} / ${task.progressTarget}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  claimed
                      ? '✓ Claimed'
                      : task.claimable
                          ? 'Claim'
                          : task.ctaType == 'action'
                              ? 'Open'
                              : 'Go',
                  style: TextStyle(
                    color: claimed
                        ? Colors.white38
                        : const Color(0xFF229ED9),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
