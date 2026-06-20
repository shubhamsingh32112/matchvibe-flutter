import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/creator_availability_toggle_provider.dart';
import '../providers/creator_dashboard_provider.dart';
import '../providers/creator_leaderboard_provider.dart';
import '../../../core/config/app_config_provider.dart';
import '../../moments/providers/moments_providers.dart';
import '../theme/creator_home_tokens.dart';
import '../widgets/home/creator_home_header.dart';
import '../widgets/home/creator_home_leaderboard_card.dart';
import '../widgets/home/creator_home_media_tabs.dart';
import '../widgets/home/creator_home_stats_tile.dart';
import '../widgets/home/creator_home_stories_section.dart';
import '../widgets/home/creator_home_tasks_section.dart';

class CreatorHomeScreen extends ConsumerStatefulWidget {
  const CreatorHomeScreen({super.key});

  @override
  ConsumerState<CreatorHomeScreen> createState() => _CreatorHomeScreenState();
}

class _CreatorHomeScreenState extends ConsumerState<CreatorHomeScreen> {
  Timer? _onlinePollTimer;

  @override
  void initState() {
    super.initState();
    _startOnlineMinutesPoll();
  }

  void _startOnlineMinutesPoll() {
    _onlinePollTimer?.cancel();
    _onlinePollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final toggleOn = ref.read(creatorAvailabilityToggleProvider).toggleOn;
      if (toggleOn) {
        ref.invalidate(creatorDashboardProvider);
      }
    });
  }

  @override
  void dispose() {
    _onlinePollTimer?.cancel();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    ref.invalidate(creatorDashboardProvider);
    ref.invalidate(creatorLeaderboardSummaryProvider);
    ref.invalidate(myStoriesProvider);
    ref.invalidate(storiesBarProvider);
    ref.invalidate(myMomentsProvider);
    final creatorId =
        ref.read(creatorDashboardProvider).valueOrNull?.creatorProfile.id;
    if (creatorId != null) {
      ref.invalidate(creatorSummaryProvider(creatorId));
    }
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    final momentsEnabled = ref.watch(appFeaturesProvider).momentsEnabled;

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: CreatorHomeTokens.textPrimary,
          displayColor: CreatorHomeTokens.textPrimary,
        ),
      ),
      child: ColoredBox(
        color: CreatorHomeTokens.pageBackground,
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: CreatorHomeTokens.primaryPurple,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  CreatorHomeTokens.sectionPaddingH,
                  8,
                  CreatorHomeTokens.sectionPaddingH,
                  24,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const CreatorHomeHeader(),
                    const CreatorHomeStatsTile(),
                    const CreatorHomeLeaderboardCard(),
                    if (momentsEnabled) const CreatorHomeStoriesSection(),
                    const CreatorHomeTasksSection(),
                    if (momentsEnabled) const CreatorHomeMediaTabs(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
