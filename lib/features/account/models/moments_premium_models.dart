enum MomentsPremiumPlanBadge { bestForTrying, mostPopular, bestValue }

MomentsPremiumPlanBadge? momentsPremiumPlanBadgeFromJson(String? raw) {
  switch (raw) {
    case 'bestForTrying':
      return MomentsPremiumPlanBadge.bestForTrying;
    case 'mostPopular':
      return MomentsPremiumPlanBadge.mostPopular;
    case 'bestValue':
      return MomentsPremiumPlanBadge.bestValue;
    default:
      return null;
  }
}

String momentsPremiumBadgeEmoji(MomentsPremiumPlanBadge badge) {
  switch (badge) {
    case MomentsPremiumPlanBadge.bestForTrying:
      return '🔥';
    case MomentsPremiumPlanBadge.mostPopular:
      return '⭐';
    case MomentsPremiumPlanBadge.bestValue:
      return '💎';
  }
}

String momentsPremiumBadgeLabel(MomentsPremiumPlanBadge badge) {
  switch (badge) {
    case MomentsPremiumPlanBadge.bestForTrying:
      return 'Best for Trying';
    case MomentsPremiumPlanBadge.mostPopular:
      return 'Most Popular';
    case MomentsPremiumPlanBadge.bestValue:
      return 'Best Value';
  }
}

class MomentsPremiumPlanOption {
  final String planId;
  final String label;
  final int durationDays;
  final int priceInr;
  final int monthlyEquivalentInr;
  final String? billedLabel;
  final MomentsPremiumPlanBadge? badge;
  final bool isActive;

  const MomentsPremiumPlanOption({
    required this.planId,
    required this.label,
    required this.durationDays,
    required this.priceInr,
    required this.monthlyEquivalentInr,
    this.billedLabel,
    this.badge,
    required this.isActive,
  });

  factory MomentsPremiumPlanOption.fromJson(Map<String, dynamic> json) {
    return MomentsPremiumPlanOption(
      planId: json['planId'] as String? ?? 'moments_1m',
      label: json['label'] as String? ?? '1 Month',
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 30,
      priceInr: (json['priceInr'] as num?)?.toInt() ?? 0,
      monthlyEquivalentInr: (json['monthlyEquivalentInr'] as num?)?.toInt() ??
          (json['priceInr'] as num?)?.toInt() ??
          0,
      billedLabel: json['billedLabel'] as String?,
      badge: momentsPremiumPlanBadgeFromJson(json['badge'] as String?),
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}

class MomentsPremiumPlansResponse {
  final List<MomentsPremiumPlanOption> plans;
  final bool momentsPremiumEnabled;

  const MomentsPremiumPlansResponse({
    required this.plans,
    required this.momentsPremiumEnabled,
  });

  factory MomentsPremiumPlansResponse.fromJson(Map<String, dynamic> json) {
    final plansRaw = json['plans'] as List<dynamic>? ?? [];
    return MomentsPremiumPlansResponse(
      plans: plansRaw
          .whereType<Map<String, dynamic>>()
          .map(MomentsPremiumPlanOption.fromJson)
          .toList(),
      momentsPremiumEnabled: json['momentsPremiumEnabled'] as bool? ?? true,
    );
  }

  MomentsPremiumPlanOption? get defaultPlan {
    for (final plan in plans) {
      if (plan.badge == MomentsPremiumPlanBadge.mostPopular && plan.isActive) {
        return plan;
      }
    }
    for (final plan in plans) {
      if (plan.isActive) return plan;
    }
    return plans.isNotEmpty ? plans.first : null;
  }

  List<MomentsPremiumPlanOption> get activePlans =>
      plans.where((plan) => plan.isActive).toList();
}

class MomentsPremiumStatus {
  final bool active;
  final DateTime? expiresAt;
  final int daysRemaining;
  final String? planId;

  const MomentsPremiumStatus({
    this.active = false,
    this.expiresAt,
    this.daysRemaining = 0,
    this.planId,
  });

  factory MomentsPremiumStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MomentsPremiumStatus();
    return MomentsPremiumStatus(
      active: json['active'] == true,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      daysRemaining: (json['daysRemaining'] as num?)?.toInt() ?? 0,
      planId: json['planId'] as String?,
    );
  }
}
