import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/loading_indicator.dart';
import '../../providers/creator_leaderboard_provider.dart';
import '../../theme/creator_home_tokens.dart';

class CreatorHomeLeaderboardCard extends ConsumerWidget {
  const CreatorHomeLeaderboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(creatorLeaderboardSummaryProvider);

    return summaryAsync.when(
      data: (summary) => Container(
        margin: const EdgeInsets.only(bottom: CreatorHomeTokens.sectionSpacing),
        padding: const EdgeInsets.all(16),
        decoration: CreatorHomeTokens.cardDecoration(),
        child: Row(
          children: [
            const _LeaderboardTrophyArt(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Leaderboard',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: CreatorHomeTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: CreatorHomeTokens.textSecondary,
                      ),
                      children: [
                        const TextSpan(text: 'Current Rank '),
                        TextSpan(
                          text: summary.rank != null
                              ? '#${summary.rank}'
                              : '—',
                          style: const TextStyle(
                            color: CreatorHomeTokens.pinkAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.push('/creator/leaderboard'),
              style: TextButton.styleFrom(
                backgroundColor: CreatorHomeTokens.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'View Ranking >',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
      loading: () => Container(
        height: 120,
        margin: const EdgeInsets.only(bottom: CreatorHomeTokens.sectionSpacing),
        decoration: CreatorHomeTokens.cardDecoration(),
        child: const Center(child: LoadingIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _LeaderboardTrophyArt extends StatelessWidget {
  const _LeaderboardTrophyArt();

  static const _assetPath = 'lib/assets/leaderboard_trophy_icon.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _assetPath,
      width: 72,
      height: 72,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Icon(
        Icons.emoji_events,
        size: 48,
        color: CreatorHomeTokens.trophyGold,
      ),
    );
  }
}
