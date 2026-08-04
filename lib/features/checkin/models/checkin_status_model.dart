/// Server-authoritative daily check-in status.
class CheckInRewardDay {
  final int day;
  final int coins;
  final String status; // claimed | today | upcoming

  const CheckInRewardDay({
    required this.day,
    required this.coins,
    required this.status,
  });

  bool get isClaimed => status == 'claimed';
  bool get isToday => status == 'today';
  bool get isUpcoming => status == 'upcoming';

  factory CheckInRewardDay.fromJson(Map<String, dynamic> json) {
    return CheckInRewardDay(
      day: (json['day'] as num?)?.toInt() ?? 0,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'upcoming',
    );
  }
}

class CheckInStatus {
  final List<CheckInRewardDay> rewards;
  final bool canClaimToday;
  final bool claimedToday;
  final int currentDayIndex;
  final DateTime resetsAt;
  final DateTime serverNow;
  final int coinsBalance;
  final bool alreadyClaimed;
  final int coinsCredited;

  const CheckInStatus({
    required this.rewards,
    required this.canClaimToday,
    required this.claimedToday,
    required this.currentDayIndex,
    required this.resetsAt,
    required this.serverNow,
    required this.coinsBalance,
    this.alreadyClaimed = false,
    this.coinsCredited = 0,
  });

  factory CheckInStatus.fromJson(Map<String, dynamic> json) {
    final rewardsRaw = json['rewards'] as List<dynamic>? ?? const [];
    return CheckInStatus(
      rewards: rewardsRaw
          .whereType<Map<String, dynamic>>()
          .map(CheckInRewardDay.fromJson)
          .toList(),
      canClaimToday: json['canClaimToday'] == true,
      claimedToday: json['claimedToday'] == true,
      currentDayIndex: (json['currentDayIndex'] as num?)?.toInt() ?? 1,
      resetsAt: DateTime.tryParse(json['resetsAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      serverNow: DateTime.tryParse(json['serverNow'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      coinsBalance: (json['coinsBalance'] as num?)?.toInt() ?? 0,
      alreadyClaimed: json['alreadyClaimed'] == true,
      coinsCredited: (json['coinsCredited'] as num?)?.toInt() ?? 0,
    );
  }
}
