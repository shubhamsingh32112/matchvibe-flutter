import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/app/widgets/app_nav_destinations.dart';
import 'package:zztherapy/core/config/app_config_model.dart';

void main() {
  const allOn = AppFeatures(vipEnabled: true, momentsEnabled: true);
  const allOff = AppFeatures();
  const vipOnly = AppFeatures(vipEnabled: true, momentsEnabled: false);
  const momentsOnly = AppFeatures(vipEnabled: false, momentsEnabled: true);

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

  test('user with vip off and moments on hides center tab', () {
    final tabs = AppNavDestinations.buildVisibleTabs(
      features: momentsOnly,
      role: 'user',
    );
    expect(tabs.map((t) => t.route).toList(), [
      '/home',
      '/moments',
      '/chat-list',
      '/account',
    ]);
  });

  test('user with vip on and moments off shows vip center only', () {
    final tabs = AppNavDestinations.buildVisibleTabs(
      features: vipOnly,
      role: 'user',
    );
    expect(tabs.map((t) => t.route).toList(), [
      '/home',
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

  test('showRecentsInNav is true for creators and both-off users', () {
    expect(AppNavDestinations.showRecentsInNav(allOn, 'creator'), isTrue);
    expect(AppNavDestinations.showRecentsInNav(allOff, 'user'), isTrue);
    expect(AppNavDestinations.showRecentsInNav(momentsOnly, 'user'), isFalse);
    expect(AppNavDestinations.showRecentsInNav(vipOnly, 'user'), isFalse);
    expect(AppNavDestinations.showRecentsInNav(allOn, 'user'), isFalse);
  });

  test('redirectForRecentRoute sends users without recents nav appropriately', () {
    expect(
      AppNavDestinations.redirectForRecentRoute(momentsOnly, 'user'),
      '/chat-list?tab=calls',
    );
    expect(
      AppNavDestinations.redirectForRecentRoute(allOn, 'user'),
      '/home',
    );
    expect(
      AppNavDestinations.redirectForRecentRoute(allOff, 'user'),
      isNull,
    );
    expect(
      AppNavDestinations.redirectForRecentRoute(allOn, 'creator'),
      isNull,
    );
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
