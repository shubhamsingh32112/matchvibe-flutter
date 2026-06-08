import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/creator_leaderboard_model.dart';
import '../services/creator_leaderboard_service.dart';

final creatorLeaderboardServiceProvider = Provider<CreatorLeaderboardService>(
  (ref) => CreatorLeaderboardService(),
);

final creatorLeaderboardSummaryProvider =
    FutureProvider<CreatorLeaderboardSummary>((ref) async {
  return ref.read(creatorLeaderboardServiceProvider).fetchSummary();
});

final creatorLeaderboardProvider =
    FutureProvider<CreatorLeaderboardResponse>((ref) async {
  return ref.read(creatorLeaderboardServiceProvider).fetchLeaderboard();
});
