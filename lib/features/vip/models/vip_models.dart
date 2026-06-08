enum VipPlanBadge { mostPopular, bestValue }

VipPlanBadge? vipPlanBadgeFromJson(String? raw) {
  switch (raw) {
    case 'mostPopular':
      return VipPlanBadge.mostPopular;
    case 'bestValue':
      return VipPlanBadge.bestValue;
    default:
      return null;
  }
}

class VipPlanOption {
  final String planId;
  final String label;
  final int durationDays;
  final int priceInr;
  final int monthlyEquivalentInr;
  final String? savingsLabel;
  final VipPlanBadge? badge;
  final bool isActive;

  const VipPlanOption({
    required this.planId,
    required this.label,
    required this.durationDays,
    required this.priceInr,
    required this.monthlyEquivalentInr,
    this.savingsLabel,
    this.badge,
    required this.isActive,
  });

  factory VipPlanOption.fromJson(Map<String, dynamic> json) {
    return VipPlanOption(
      planId: json['planId'] as String? ?? 'vip_monthly',
      label: json['label'] as String? ?? 'VIP',
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 30,
      priceInr: (json['priceInr'] as num?)?.toInt() ?? 0,
      monthlyEquivalentInr: (json['monthlyEquivalentInr'] as num?)?.toInt() ??
          (json['priceInr'] as num?)?.toInt() ??
          0,
      savingsLabel: json['savingsLabel'] as String?,
      badge: vipPlanBadgeFromJson(json['badge'] as String?),
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}

class VipPlansPerks {
  final int freeMomentsPerDay;
  final int rechargeDiscountPercent;
  final int momentDiscountPercent;

  const VipPlansPerks({
    required this.freeMomentsPerDay,
    required this.rechargeDiscountPercent,
    required this.momentDiscountPercent,
  });

  factory VipPlansPerks.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const VipPlansPerks(
        freeMomentsPerDay: 10,
        rechargeDiscountPercent: 10,
        momentDiscountPercent: 10,
      );
    }
    return VipPlansPerks(
      freeMomentsPerDay: (json['freeMomentsPerDay'] as num?)?.toInt() ?? 10,
      rechargeDiscountPercent:
          (json['rechargeDiscountPercent'] as num?)?.toInt() ?? 10,
      momentDiscountPercent:
          (json['momentDiscountPercent'] as num?)?.toInt() ?? 10,
    );
  }
}

class VipPlansResponse {
  final List<VipPlanOption> plans;
  final VipPlansPerks perks;

  const VipPlansResponse({
    required this.plans,
    required this.perks,
  });

  factory VipPlansResponse.fromJson(Map<String, dynamic> json) {
    final plansRaw = json['plans'] as List<dynamic>?;
    if (plansRaw != null && plansRaw.isNotEmpty) {
      return VipPlansResponse(
        plans: plansRaw
            .whereType<Map<String, dynamic>>()
            .map(VipPlanOption.fromJson)
            .toList(),
        perks: VipPlansPerks.fromJson(
          json['perks'] as Map<String, dynamic>?,
        ),
      );
    }

    // Backward-compatible single-plan payload.
    return VipPlansResponse(
      plans: [VipPlanOption.fromJson(json)],
      perks: VipPlansPerks.fromJson(json),
    );
  }

  VipPlanOption? get defaultPlan {
    for (final plan in plans) {
      if (plan.badge == VipPlanBadge.mostPopular && plan.isActive) {
        return plan;
      }
    }
    for (final plan in plans) {
      if (plan.isActive) return plan;
    }
    return plans.isNotEmpty ? plans.first : null;
  }

  List<VipPlanOption> get activePlans =>
      plans.where((plan) => plan.isActive).toList();
}

/// Legacy alias kept for any code still referencing a single plan.
class VipPlan {
  final String planId;
  final int durationDays;
  final int priceInr;
  final bool isActive;
  final List<String> perks;
  final int freeMomentsPerDay;
  final int rechargeDiscountPercent;
  final int momentDiscountPercent;

  const VipPlan({
    required this.planId,
    required this.durationDays,
    required this.priceInr,
    required this.isActive,
    required this.perks,
    required this.freeMomentsPerDay,
    required this.rechargeDiscountPercent,
    required this.momentDiscountPercent,
  });

  factory VipPlan.fromJson(Map<String, dynamic> json) {
    return VipPlan(
      planId: json['planId'] as String? ?? 'vip_monthly',
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 30,
      priceInr: (json['priceInr'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? false,
      perks: (json['perks'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      freeMomentsPerDay: (json['freeMomentsPerDay'] as num?)?.toInt() ?? 10,
      rechargeDiscountPercent:
          (json['rechargeDiscountPercent'] as num?)?.toInt() ?? 10,
      momentDiscountPercent:
          (json['momentDiscountPercent'] as num?)?.toInt() ?? 10,
    );
  }

  factory VipPlan.fromPlansResponse(VipPlansResponse response) {
    final option = response.defaultPlan;
    if (option == null) {
      return const VipPlan(
        planId: 'vip_monthly',
        durationDays: 30,
        priceInr: 0,
        isActive: false,
        perks: [],
        freeMomentsPerDay: 10,
        rechargeDiscountPercent: 10,
        momentDiscountPercent: 10,
      );
    }
    return VipPlan(
      planId: option.planId,
      durationDays: option.durationDays,
      priceInr: option.priceInr,
      isActive: option.isActive,
      perks: [
        '${response.perks.freeMomentsPerDay} free paid moments per day',
        'Unlimited free messages',
        '${response.perks.rechargeDiscountPercent}% off coin recharges',
        '${response.perks.momentDiscountPercent}% off moments after daily free quota',
        'VIP badge',
        'Priority calling when creators are busy',
        'Schedule calls with creators',
      ],
      freeMomentsPerDay: response.perks.freeMomentsPerDay,
      rechargeDiscountPercent: response.perks.rechargeDiscountPercent,
      momentDiscountPercent: response.perks.momentDiscountPercent,
    );
  }
}

class VipStatus {
  final bool active;
  final DateTime? expiresAt;
  final int daysRemaining;
  final String? planId;
  final int freeMomentsRemainingToday;
  final int freeMomentsDailyLimit;
  final int rechargeDiscountPercent;
  final int momentDiscountPercent;

  const VipStatus({
    this.active = false,
    this.expiresAt,
    this.daysRemaining = 0,
    this.planId,
    this.freeMomentsRemainingToday = 0,
    this.freeMomentsDailyLimit = 10,
    this.rechargeDiscountPercent = 10,
    this.momentDiscountPercent = 10,
  });

  factory VipStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const VipStatus();
    return VipStatus(
      active: json['active'] == true,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      daysRemaining: (json['daysRemaining'] as num?)?.toInt() ?? 0,
      planId: json['planId'] as String?,
      freeMomentsRemainingToday:
          (json['freeMomentsRemainingToday'] as num?)?.toInt() ?? 0,
      freeMomentsDailyLimit:
          (json['freeMomentsDailyLimit'] as num?)?.toInt() ?? 10,
      rechargeDiscountPercent:
          (json['rechargeDiscountPercent'] as num?)?.toInt() ?? 10,
      momentDiscountPercent:
          (json['momentDiscountPercent'] as num?)?.toInt() ?? 10,
    );
  }
}
