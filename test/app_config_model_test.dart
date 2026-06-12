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
        'welcomeIntroCallCredits': 30,
        'minCoinsToCall': 10,
      },
    });

    expect(config.features.vipEnabled, isTrue);
    expect(config.features.momentsEnabled, isFalse);
    expect(config.pricing.welcomeIntroCallCredits, 30);
    expect(config.pricing.minCoinsToCall, 10);
  });

  test('AppConfig.safeDefaults locks features off', () {
    final config = AppConfig.safeDefaults();
    expect(config.features.vipEnabled, isFalse);
    expect(config.features.momentsEnabled, isFalse);
    expect(config.pricing.welcomeIntroCallCredits, 60);
  });
}
