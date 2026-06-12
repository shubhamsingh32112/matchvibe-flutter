import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/app/widgets/app_nav_destinations.dart';
import 'package:zztherapy/core/config/app_config_model.dart';

void main() {
  const allOn = AppFeatures(vipEnabled: true, momentsEnabled: true);
  const allOff = AppFeatures();

  test('user with all features sees moments and vip center tabs', () {
    final tabs = AppNavDestinations.buildVisibleTabs(
      features: allOn,
      role: 'user',
    );
    expect(tabs.map((t) => t.route).toList(), [
      '/home',
      '/moments',
      '/vip',
      '/chat-list',
      '/account',
    ]);
  });

  test('user with features off hides moments and routes center to recent', () {
    final tabs = AppNavDestinations.buildVisibleTabs(
      features: allOff,
      role: 'user',
    );
    expect(tabs.map((t) => t.route).toList(), [
      '/home',
      '/recent',
      '/chat-list',
      '/account',
    ]);
  });

  test('creator always uses recent center tab', () {
    final tabs = AppNavDestinations.buildVisibleTabs(
      features: allOn,
      role: 'creator',
    );
    expect(tabs.map((t) => t.route).toList(), [
      '/home',
      '/moments',
      '/recent',
      '/chat-list',
      '/account',
    ]);
  });

  test('indexForRoute resolves profile and center aliases', () {
    final tabs = AppNavDestinations.buildVisibleTabs(
      features: allOff,
      role: 'user',
    );
    expect(AppNavDestinations.indexForRoute('/account', tabs), 3);
    expect(AppNavDestinations.indexForRoute('/recent', tabs), 1);
  });
}
