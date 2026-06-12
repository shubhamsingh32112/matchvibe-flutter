import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_config_model.dart';
import 'app_config_service.dart';

class AppConfigNotifier extends StateNotifier<AppConfig> {
  AppConfigNotifier() : super(AppConfig.safeDefaults()) {
    appConfigSnapshot = state;
  }

  final AppConfigService _service = AppConfigService();
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final config = await _service.fetch();
      state = config;
      appConfigSnapshot = config;
      _loaded = true;
    } catch (_) {
      state = AppConfig.safeDefaults();
      appConfigSnapshot = state;
      _loaded = true;
    }
  }

  void applyFeatures(AppFeatures features) {
    state = AppConfig(features: features, pricing: state.pricing);
    appConfigSnapshot = state;
  }
}

final appConfigProvider =
    StateNotifierProvider<AppConfigNotifier, AppConfig>((ref) {
  return AppConfigNotifier();
});

final appFeaturesProvider = Provider<AppFeatures>((ref) {
  return ref.watch(appConfigProvider).features;
});
