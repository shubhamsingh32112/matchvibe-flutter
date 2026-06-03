/// Bottom navigation index ↔ route mapping (5 tabs for all roles).
class AppNavDestinations {
  AppNavDestinations._();

  static const int homeIndex = 0;
  static const int momentsIndex = 1;
  static const int centerIndex = 2;
  static const int chatIndex = 3;
  static const int profileIndex = 4;

  static bool isCreatorOrAdmin(String? role) =>
      role == 'creator' || role == 'admin';

  static String routeForIndex(String? role, int index) {
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
