import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config_provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'app_nav_destinations.dart';

int appNavSelectedIndex(WidgetRef ref, String route) {
  final tabs = ref.watch(appNavTabsProvider);
  return AppNavDestinations.indexForRoute(route, tabs);
}

final appNavTabsProvider = Provider<List<AppNavTab>>((ref) {
  final features = ref.watch(appFeaturesProvider);
  final role = ref.watch(
    authProvider.select((s) => s.user?.role),
  );
  return AppNavDestinations.buildVisibleTabs(
    features: features,
    role: role,
  );
});
