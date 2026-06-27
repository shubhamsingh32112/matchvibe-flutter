class AppFeatures {
  final bool vipEnabled;
  final bool momentsEnabled;
  /// Consumed only by [momentsAccessStateProvider] — not for direct widget use.
  final String momentsAccessMode;

  const AppFeatures({
    this.vipEnabled = false,
    this.momentsEnabled = false,
    this.momentsAccessMode = 'paid',
  });

  bool get isMomentsFreeAccessMode => momentsAccessMode == 'free';
  bool get isMomentsPaidAccessMode => momentsAccessMode != 'free';

  factory AppFeatures.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AppFeatures();
    final rawMode = json['momentsAccessMode'] as String? ?? 'paid';
    return AppFeatures(
      vipEnabled: json['vipEnabled'] == true,
      momentsEnabled: json['momentsEnabled'] == true,
      momentsAccessMode: rawMode == 'free' ? 'free' : 'paid',
    );
  }

  AppFeatures copyWith({
    bool? vipEnabled,
    bool? momentsEnabled,
    String? momentsAccessMode,
  }) {
    return AppFeatures(
      vipEnabled: vipEnabled ?? this.vipEnabled,
      momentsEnabled: momentsEnabled ?? this.momentsEnabled,
      momentsAccessMode: momentsAccessMode ?? this.momentsAccessMode,
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
    this.minCoinsToCall = 10,
  });

  factory AppPricingConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AppPricingConfig();
    return AppPricingConfig(
      freeCallEnabled: json['freeCallEnabled'] != false,
      freeCallDurationSeconds:
          (json['freeCallDurationSeconds'] as num?)?.toInt() ?? 30,
      welcomeIntroCallCredits:
          (json['welcomeIntroCallCredits'] as num?)?.toInt() ?? 30,
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
