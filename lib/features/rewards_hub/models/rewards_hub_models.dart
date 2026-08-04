class RewardsHubTask {
  final String key;
  final String title;
  final String description;
  final int coins;
  final String cadence;
  final String status;
  final int? progressCurrent;
  final int? progressTarget;
  final bool claimed;
  final bool claimable;
  final String ctaType;
  final String ctaValue;

  const RewardsHubTask({
    required this.key,
    required this.title,
    required this.description,
    required this.coins,
    required this.cadence,
    required this.status,
    this.progressCurrent,
    this.progressTarget,
    required this.claimed,
    required this.claimable,
    required this.ctaType,
    required this.ctaValue,
  });

  factory RewardsHubTask.fromJson(Map<String, dynamic> json) {
    final progress = json['progress'] as Map<String, dynamic>?;
    final cta = json['cta'] as Map<String, dynamic>? ?? {};
    return RewardsHubTask(
      key: json['key']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      cadence: json['cadence']?.toString() ?? 'once',
      status: json['status']?.toString() ?? 'available',
      progressCurrent: (progress?['current'] as num?)?.toInt(),
      progressTarget: (progress?['target'] as num?)?.toInt(),
      claimed: json['claimed'] == true,
      claimable: json['claimable'] == true,
      ctaType: cta['type']?.toString() ?? 'route',
      ctaValue: cta['value']?.toString() ?? '',
    );
  }
}

class RewardsHubData {
  final bool enabled;
  final int coinsBalance;
  final List<RewardsHubTask> tasks;

  const RewardsHubData({
    required this.enabled,
    required this.coinsBalance,
    required this.tasks,
  });

  factory RewardsHubData.fromJson(Map<String, dynamic> json) {
    final list = json['tasks'];
    return RewardsHubData(
      enabled: json['enabled'] != false,
      coinsBalance: (json['coinsBalance'] as num?)?.toInt() ?? 0,
      tasks: list is List
          ? list
              .whereType<Map>()
              .map((e) => RewardsHubTask.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

class RewardsClaimResult {
  final bool alreadyClaimed;
  final int coinsCredited;
  final int balance;

  const RewardsClaimResult({
    required this.alreadyClaimed,
    required this.coinsCredited,
    required this.balance,
  });

  factory RewardsClaimResult.fromJson(Map<String, dynamic> json) {
    return RewardsClaimResult(
      alreadyClaimed: json['alreadyClaimed'] == true,
      coinsCredited: (json['coinsCredited'] as num?)?.toInt() ?? 0,
      balance: (json['balance'] as num?)?.toInt() ?? 0,
    );
  }
}
