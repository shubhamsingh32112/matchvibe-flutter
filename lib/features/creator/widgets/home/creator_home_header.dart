import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config_provider.dart';
import '../../../../core/utils/compact_count_formatter.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../moments/providers/moments_providers.dart';
import '../../providers/creator_dashboard_provider.dart';
import '../../providers/creator_status_provider.dart';
import '../../theme/creator_home_tokens.dart';
import 'creator_home_availability_switch.dart';

class CreatorHomeHeader extends ConsumerWidget {
  const CreatorHomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider.select((s) => s.user));
    final displayName = (user?.name?.trim().isNotEmpty == true
            ? user!.name!
            : user?.username)
        ?.trim();
    final name = displayName?.isNotEmpty == true ? displayName! : 'Creator';
    final status = ref.watch(creatorStatusProvider);
    final momentsEnabled = ref.watch(appFeaturesProvider).momentsEnabled;
    final creatorId = ref.watch(
      creatorDashboardProvider.select((a) => a.valueOrNull?.creatorProfile.id),
    );
    final summaryAsync = creatorId != null && momentsEnabled
        ? ref.watch(creatorSummaryProvider(creatorId))
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: CreatorHomeTokens.sectionSpacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppAvatar(
            avatarAsset: user?.avatarAsset,
            size: 120,
            fallbackText: name.isNotEmpty ? name[0] : 'C',
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Hi, $name',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: CreatorHomeTokens.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.verified,
                      size: 18,
                      color: CreatorHomeTokens.primaryPurple,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _AvailabilityPill(status: status),
                if (summaryAsync != null) ...[
                  const SizedBox(height: 6),
                  summaryAsync.when(
                    data: (summary) => Text(
                      '${formatCompactCount(summary.followerCount)} Followers',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CreatorHomeTokens.textPrimary.withValues(
                          alpha: 0.85,
                        ),
                      ),
                    ),
                    loading: () => Text(
                      '— Followers',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CreatorHomeTokens.labelGrey,
                      ),
                    ),
                    error: (_, __) => Text(
                      '— Followers',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CreatorHomeTokens.labelGrey,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const CreatorHomeAvailabilitySwitch(),
        ],
      ),
    );
  }
}

class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({required this.status});

  final CreatorStatus status;

  @override
  Widget build(BuildContext context) {
    final isOnline = status == CreatorStatus.online;
    final isOnCall = status == CreatorStatus.onCall;
    final label = isOnCall
        ? 'On call'
        : isOnline
        ? 'Online'
        : 'Offline';
    final color = isOnCall
        ? Colors.orange
        : isOnline
        ? CreatorHomeTokens.completedGreen
        : CreatorHomeTokens.labelGrey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.keyboard_arrow_down, size: 16, color: color),
        ],
      ),
    );
  }
}
