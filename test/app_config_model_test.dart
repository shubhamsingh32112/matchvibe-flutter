import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/core/config/app_config_model.dart';

void main() {
  test('AppConfig.fromJson parses features and pricing', () {
    final config = AppConfig.fromJson({
      'features': {
        'vipEnabled': true,
        'momentsEnabled': false,
      },
      'pricing': {
        'freeCallEnabled': true,
        'freeCallDurationSeconds': 45,
        'welcomeIntroCallCredits': 45,
        'minCoinsToCall': 10,
      },
    });

    expect(config.features.vipEnabled, isTrue);
    expect(config.features.momentsEnabled, isFalse);
    expect(config.features.momentsAccessMode, 'paid');
    expect(config.pricing.freeCallEnabled, isTrue);
    expect(config.pricing.freeCallDurationSeconds, 45);
    expect(config.pricing.welcomeIntroCallCredits, 45);
    expect(config.pricing.minCoinsToCall, 10);
  });

  test('AppFeatures parses momentsAccessMode free', () {
    final features = AppFeatures.fromJson({
      'momentsEnabled': true,
      'momentsAccessMode': 'free',
    });
    expect(features.isMomentsFreeAccessMode, isTrue);
    expect(features.isMomentsPaidAccessMode, isFalse);
  });

  test('AppConfig.safeDefaults locks features off', () {
    final config = AppConfig.safeDefaults();
    expect(config.features.vipEnabled, isFalse);
    expect(config.features.momentsEnabled, isFalse);
    expect(config.pricing.freeCallEnabled, isTrue);
    expect(config.pricing.freeCallDurationSeconds, 30);
    expect(config.pricing.welcomeIntroCallCredits, 30);
  });
}
