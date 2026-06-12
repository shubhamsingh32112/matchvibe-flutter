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

  static List<AppNavTab> buildVisibleTabs({
    required AppFeatures features,
    required String? role,
  }) {
    final isCreator = isCreatorOrAdmin(role);
    final showVipCenter = !isCreator && features.vipEnabled;
    final centerRoute = isCreator
        ? '/recent'
        : (showVipCenter ? '/vip' : '/recent');

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
      AppNavTab(
        id: AppNavTabId.center,
        route: centerRoute,
        tooltip: showVipCenter ? 'VIP' : 'Recent',
        assetIconPath: showVipCenter ? AppNavAssets.vipIcon : null,
        icon: showVipCenter ? null : Icons.history_outlined,
        selectedIcon: showVipCenter ? null : Icons.history,
        iconSize: showVipCenter ? vipNavIconSize : navIconSize,
        iconSizeSelected:
            showVipCenter ? vipNavIconSizeSelected : navIconSizeSelected,
        iconHitSize: showVipCenter ? vipNavIconHitSize : navIconHitSize,
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
      return tabs.indexWhere((tab) => tab.id == AppNavTabId.center);
    }
    if (normalized.startsWith('/recent')) {
      return tabs.indexWhere((tab) => tab.id == AppNavTabId.center);
    }
    if (normalized.startsWith('/account')) {
      return tabs.indexWhere((tab) => tab.id == AppNavTabId.profile);
    }
    if (normalized.startsWith('/chat')) {
      return tabs.indexWhere((tab) => tab.id == AppNavTabId.chat);
    }
    return 0;
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
