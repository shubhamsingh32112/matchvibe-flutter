import 'package:flutter/material.dart';
import '../../core/config/app_config_model.dart';
import 'app_nav_assets.dart';

enum AppNavTabId { home, moments, center, chat, profile }

class AppNavTab {
  final AppNavTabId id;
  final String route;
  final String tooltip;
  final String? assetIconPath;
  final IconData? icon;
  final IconData? selectedIcon;
  final double? iconSize;
  final double? iconSizeSelected;
  final double? iconHitSize;

  const AppNavTab({
    required this.id,
    required this.route,
    required this.tooltip,
    this.assetIconPath,
    this.icon,
    this.selectedIcon,
    this.iconSize,
    this.iconSizeSelected,
    this.iconHitSize,
  });
}

/// Bottom navigation index ↔ route mapping.
class AppNavDestinations {
  AppNavDestinations._();

  static const int homeIndex = 0;
  static const int momentsIndex = 1;
  static const int centerIndex = 2;
  static const int chatIndex = 3;
  static const int profileIndex = 4;

  static bool isCreatorOrAdmin(String? role) =>
      role == 'creator' || role == 'admin';

  /// Whether Recents appears as a bottom-nav center tab (not Chat sub-tab).
  static bool showRecentsInNav(AppFeatures features, String? role) {
    if (isCreatorOrAdmin(role)) return true;
    return !features.vipEnabled && !features.momentsEnabled;
  }

  static List<AppNavTab> buildVisibleTabs({
    required AppFeatures features,
    required String? role,
  }) {
    final isCreator = isCreatorOrAdmin(role);
    final showVipCenter = !isCreator && features.vipEnabled;
    final showRecentsCenter = showRecentsInNav(features, role);

    return [
      const AppNavTab(
        id: AppNavTabId.home,
        route: '/home',
        tooltip: 'Home',
        assetIconPath: AppNavAssets.homeIcon,
      ),
      if (features.momentsEnabled)
        const AppNavTab(
          id: AppNavTabId.moments,
          route: '/moments',
          tooltip: 'Moments',
          assetIconPath: AppNavAssets.momentsIcon,
        ),
      if (showVipCenter)
        const AppNavTab(
          id: AppNavTabId.center,
          route: '/vip',
          tooltip: 'VIP',
          assetIconPath: AppNavAssets.vipIcon,
          iconSize: vipNavIconSize,
          iconSizeSelected: vipNavIconSizeSelected,
          iconHitSize: vipNavIconHitSize,
        ),
      if (showRecentsCenter && !showVipCenter)
        const AppNavTab(
          id: AppNavTabId.center,
          route: '/recent',
          tooltip: 'Recents',
          icon: Icons.history_outlined,
          selectedIcon: Icons.history,
          iconSize: navIconSize,
          iconSizeSelected: navIconSizeSelected,
          iconHitSize: navIconHitSize,
        ),
      const AppNavTab(
        id: AppNavTabId.chat,
        route: '/chat-list',
        tooltip: 'Chats',
        assetIconPath: AppNavAssets.chatsIcon,
      ),
      const AppNavTab(
        id: AppNavTabId.profile,
        route: '/account',
        tooltip: 'Profile',
        assetIconPath: AppNavAssets.profileIcon,
      ),
    ];
  }

  static int indexForRoute(String route, List<AppNavTab> tabs) {
    final normalized = _normalizeRoute(route);
    final idx = tabs.indexWhere((tab) => tab.route == normalized);
    if (idx >= 0) return idx;

    if (normalized.startsWith('/vip')) {
      final centerIdx =
          tabs.indexWhere((tab) => tab.id == AppNavTabId.center);
      return centerIdx >= 0 ? centerIdx : 0;
    }
    if (normalized.startsWith('/recent')) {
      final centerIdx =
          tabs.indexWhere((tab) => tab.id == AppNavTabId.center);
      return centerIdx >= 0 ? centerIdx : 0;
    }
    if (normalized.startsWith('/account')) {
      final profileIdx =
          tabs.indexWhere((tab) => tab.id == AppNavTabId.profile);
      return profileIdx >= 0 ? profileIdx : 0;
    }
    if (normalized.startsWith('/chat')) {
      final chatIdx = tabs.indexWhere((tab) => tab.id == AppNavTabId.chat);
      return chatIdx >= 0 ? chatIdx : 0;
    }
    return 0;
  }

  /// Redirect when `/recent` is opened but Recents is not in bottom nav.
  static String? redirectForRecentRoute(AppFeatures features, String? role) {
    if (showRecentsInNav(features, role)) return null;
    if (!features.vipEnabled && features.momentsEnabled) {
      return '/chat-list?tab=calls';
    }
    return '/home';
  }

  static String routeForIndex(List<AppNavTab> tabs, int index) {
    if (index < 0 || index >= tabs.length) return '/home';
    return tabs[index].route;
  }

  static String routeForIndexLegacy(String? role, int index) {
    switch (index) {
      case homeIndex:
        return '/home';
      case momentsIndex:
        return '/moments';
      case centerIndex:
        return isCreatorOrAdmin(role) ? '/recent' : '/vip';
      case chatIndex:
        return '/chat-list';
      case profileIndex:
        return '/account';
      default:
        return '/home';
    }
  }

  static String _normalizeRoute(String route) {
    if (route == '/chat') return '/chat-list';
    return route;
  }

  /// Height of the nav strip (excluding safe area).
  static const double barHeight = 80;

  /// Top corner radius of the nav bar.
  static const double barTopCornerRadius = 24;

  static const double navIconSizeSelected = 34;
  static const double navIconSize = 32;
  static const double navIconHitSize = 44;

  /// Slightly larger than [navIconSize] for the center VIP tab.
  static const double vipNavIconSizeSelected = 46;
  static const double vipNavIconSize = 44;
  static const double vipNavIconHitSize = 54;
}
