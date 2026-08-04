class TelegramRewardStatus {
  final bool enabled;
  final bool claimed;
  final bool linked;
  final String channelUrl;
  final int rewardCoins;
  final String botUsername;
  final int coinsBalance;
  final bool misconfigured;

  const TelegramRewardStatus({
    required this.enabled,
    required this.claimed,
    required this.linked,
    required this.channelUrl,
    required this.rewardCoins,
    required this.botUsername,
    required this.coinsBalance,
    this.misconfigured = false,
  });

  bool get shouldShowFab => enabled && !claimed && !misconfigured;

  factory TelegramRewardStatus.fromJson(Map<String, dynamic> json) {
    return TelegramRewardStatus(
      enabled: json['enabled'] == true,
      claimed: json['claimed'] == true,
      linked: json['linked'] == true,
      channelUrl: json['channelUrl']?.toString() ?? '',
      rewardCoins: (json['rewardCoins'] as num?)?.toInt() ?? 100,
      botUsername: json['botUsername']?.toString() ?? '',
      coinsBalance: (json['coinsBalance'] as num?)?.toInt() ?? 0,
      misconfigured: json['misconfigured'] == true,
    );
  }

  TelegramRewardStatus copyWith({
    bool? enabled,
    bool? claimed,
    bool? linked,
    String? channelUrl,
    int? rewardCoins,
    String? botUsername,
    int? coinsBalance,
    bool? misconfigured,
  }) {
    return TelegramRewardStatus(
      enabled: enabled ?? this.enabled,
      claimed: claimed ?? this.claimed,
      linked: linked ?? this.linked,
      channelUrl: channelUrl ?? this.channelUrl,
      rewardCoins: rewardCoins ?? this.rewardCoins,
      botUsername: botUsername ?? this.botUsername,
      coinsBalance: coinsBalance ?? this.coinsBalance,
      misconfigured: misconfigured ?? this.misconfigured,
    );
  }
}

class TelegramLinkToken {
  final String deepLink;
  final int expiresInSeconds;

  const TelegramLinkToken({
    required this.deepLink,
    required this.expiresInSeconds,
  });

  factory TelegramLinkToken.fromJson(Map<String, dynamic> json) {
    return TelegramLinkToken(
      deepLink: json['deepLink']?.toString() ?? '',
      expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt() ?? 1800,
    );
  }
}

class TelegramVerifyResult {
  final bool success;
  final bool alreadyClaimed;
  final int coinsCredited;
  final int coins;
  final int balance;

  const TelegramVerifyResult({
    required this.success,
    required this.alreadyClaimed,
    required this.coinsCredited,
    required this.coins,
    required this.balance,
  });

  factory TelegramVerifyResult.fromJson(Map<String, dynamic> json) {
    return TelegramVerifyResult(
      success: json['success'] != false,
      alreadyClaimed: json['alreadyClaimed'] == true,
      coinsCredited: (json['coinsCredited'] as num?)?.toInt() ?? 0,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      balance: (json['balance'] as num?)?.toInt() ?? 0,
    );
  }
}

class TelegramRewardException implements Exception {
  final String message;
  final String? code;

  TelegramRewardException(this.message, {this.code});

  @override
  String toString() => message;
}
