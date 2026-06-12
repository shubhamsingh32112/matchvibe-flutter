class AppFeatures {
  final bool vipEnabled;
  final bool momentsEnabled;

  const AppFeatures({
    this.vipEnabled = false,
    this.momentsEnabled = false,
  });

  factory AppFeatures.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AppFeatures();
    return AppFeatures(
      vipEnabled: json['vipEnabled'] == true,
      momentsEnabled: json['momentsEnabled'] == true,
    );
  }

  AppFeatures copyWith({
    bool? vipEnabled,
    bool? momentsEnabled,
  }) {
    return AppFeatures(
      vipEnabled: vipEnabled ?? this.vipEnabled,
      momentsEnabled: momentsEnabled ?? this.momentsEnabled,
    );
  }
}

class AppPricingConfig {
  final int welcomeIntroCallCredits;
  final int minCoinsToCall;

  const AppPricingConfig({
    this.welcomeIntroCallCredits = 60,
    this.minCoinsToCall = 10,
  });

  factory AppPricingConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AppPricingConfig();
    return AppPricingConfig(
      welcomeIntroCallCredits:
          (json['welcomeIntroCallCredits'] as num?)?.toInt() ?? 60,
      minCoinsToCall: (json['minCoinsToCall'] as num?)?.toInt() ?? 10,
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
