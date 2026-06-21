import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/compact_count_formatter.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../../../shared/widgets/gem_icon.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/creator_leaderboard_provider.dart';
import '../theme/creator_home_tokens.dart';

class CreatorLeaderboardScreen extends ConsumerWidget {
  const CreatorLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(creatorLeaderboardProvider);
    final summaryAsync = ref.watch(creatorLeaderboardSummaryProvider);

    return Scaffold(
      backgroundColor: CreatorHomeTokens.pageBackground,
      appBar: buildAccountFlowAppBar(context, title: 'Leaderboard'),
      body: leaderboardAsync.when(
        data: (data) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(creatorLeaderboardProvider);
              ref.invalidate(creatorLeaderboardSummaryProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                summaryAsync.when(
                  data: (summary) => Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: CreatorHomeTokens.cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.rank != null
                              ? 'Your rank: #${summary.rank}'
                              : 'Your rank: not in top ${data.rows.length}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: CreatorHomeTokens.pinkAccent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const GemIcon(size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Top ${summary.topRewardRank} win ${summary.topRewardCoins} coins',
                              style: const TextStyle(
                                fontSize: 13,
                                color: CreatorHomeTokens.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                ...data.rows.map(
                  (row) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: CreatorHomeTokens.cardDecoration(),
                    child: Row(
                      children: [
                        Text(
                          '#${row.rank}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: CreatorHomeTokens.primaryPurple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: row.avatarUrl != null
                              ? NetworkImage(row.avatarUrl!)
                              : null,
                          child: row.avatarUrl == null
                              ? const Icon(Icons.person, size: 20)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.hostName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: CreatorHomeTokens.textPrimary,
                                ),
                              ),
                              Text(
                                '${row.talkMinutes.toStringAsFixed(0)} min · ${row.callCount} calls · ${formatCompactCount(row.followerCount)} followers',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: CreatorHomeTokens.labelGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const GemIcon(size: 14),
                            const SizedBox(width: 2),
                            Text(
                              '${row.earningsCoins}',
                              style: const TextStyle(
                                color: CreatorHomeTokens.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: LoadingIndicator()),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(creatorLeaderboardProvider),
            child: const Text('Retry'),
          ),
        ),
      ),
    );
  }
}
