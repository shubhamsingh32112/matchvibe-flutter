class AppFeatures {
  final bool vipEnabled;
  final bool vipProfileFrameEnabled;
  final bool momentsEnabled;
  /// Consumed only by [momentsAccessStateProvider] — not for direct widget use.
  final String momentsAccessMode;
  final bool dailyCheckInEnabled;
  final bool telegramRewardEnabled;
  final bool consumerRewardsEnabled;

  const AppFeatures({
    this.vipEnabled = false,
    this.vipProfileFrameEnabled = false,
    this.momentsEnabled = false,
    this.momentsAccessMode = 'paid',
    this.dailyCheckInEnabled = false,
    this.telegramRewardEnabled = false,
    this.consumerRewardsEnabled = false,
  });

  bool get isMomentsFreeAccessMode => momentsAccessMode == 'free';
  bool get isMomentsPaidAccessMode => momentsAccessMode != 'free';

  factory AppFeatures.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AppFeatures();
    final rawMode = json['momentsAccessMode'] as String? ?? 'paid';
    return AppFeatures(
      vipEnabled: json['vipEnabled'] == true,
      vipProfileFrameEnabled: json['vipProfileFrameEnabled'] == true,
      momentsEnabled: json['momentsEnabled'] == true,
      momentsAccessMode: rawMode == 'free' ? 'free' : 'paid',
      dailyCheckInEnabled: json['dailyCheckInEnabled'] == true,
      telegramRewardEnabled: json['telegramRewardEnabled'] == true,
      consumerRewardsEnabled: json['consumerRewardsEnabled'] == true,
    );
  }

  AppFeatures copyWith({
    bool? vipEnabled,
    bool? vipProfileFrameEnabled,
    bool? momentsEnabled,
    String? momentsAccessMode,
    bool? dailyCheckInEnabled,
    bool? telegramRewardEnabled,
    bool? consumerRewardsEnabled,
  }) {
    return AppFeatures(
      vipEnabled: vipEnabled ?? this.vipEnabled,
      vipProfileFrameEnabled:
          vipProfileFrameEnabled ?? this.vipProfileFrameEnabled,
      momentsEnabled: momentsEnabled ?? this.momentsEnabled,
      momentsAccessMode: momentsAccessMode ?? this.momentsAccessMode,
      dailyCheckInEnabled: dailyCheckInEnabled ?? this.dailyCheckInEnabled,
      telegramRewardEnabled:
          telegramRewardEnabled ?? this.telegramRewardEnabled,
      consumerRewardsEnabled:
          consumerRewardsEnabled ?? this.consumerRewardsEnabled,
    );
  }
}

class AppPricingConfig {
  final bool freeCallEnabled;
  final int freeCallDurationSeconds;
  final int welcomeIntroCallCredits;
  final int minCoinsToCall;

  const AppPricingConfig({
    this.freeCallEnabled = true,
    this.freeCallDurationSeconds = 30,
    this.welcomeIntroCallCredits = 30,
    this.minCoinsToCall = 450,
  });

  factory AppPricingConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AppPricingConfig();
    return AppPricingConfig(
      freeCallEnabled: json['freeCallEnabled'] != false,
      freeCallDurationSeconds:
          (json['freeCallDurationSeconds'] as num?)?.toInt() ?? 30,
      welcomeIntroCallCredits:
          (json['welcomeIntroCallCredits'] as num?)?.toInt() ?? 30,
      minCoinsToCall: (json['minCoinsToCall'] as num?)?.toInt() ?? 450,
    );
  }
}

class AppConfig {
  final AppFeatures features;
  final AppPricingConfig pricing;

  const AppConfig({
    required this.features,
    required this.pricing,
  });

  factory AppConfig.safeDefaults() {
    return const AppConfig(
      features: AppFeatures(),
      pricing: AppPricingConfig(),
    );
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      features: AppFeatures.fromJson(json['features'] as Map<String, dynamic>?),
      pricing: AppPricingConfig.fromJson(
        json['pricing'] as Map<String, dynamic>?,
      ),
    );
  }
}

/// Snapshot for GoRouter redirects (updated when [appConfigProvider] loads).
AppConfig appConfigSnapshot = AppConfig.safeDefaults();
