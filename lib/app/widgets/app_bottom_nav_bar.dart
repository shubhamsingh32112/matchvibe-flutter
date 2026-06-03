import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/chat/providers/stream_chat_provider.dart';
import '../../shared/styles/app_brand_styles.dart';
import 'app_nav_assets.dart';
import 'app_nav_bar_shape.dart';
import 'app_nav_destinations.dart';

class AppBottomNavBar extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool showVipCenter;

  const AppBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.showVipCenter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(
      chatUnreadCountProvider.select((a) => a.valueOrNull ?? 0),
    );
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final barStripHeight = AppNavDestinations.barHeight + bottomInset;

    final navRow = Row(
      children: [
        Expanded(
          child: _NavItem(
            tooltip: 'Home',
            assetIconPath: AppNavAssets.homeIcon,
            selected: selectedIndex == AppNavDestinations.homeIndex,
            showDot: false,
            onTap: () => onDestinationSelected(AppNavDestinations.homeIndex),
          ),
        ),
        Expanded(
          child: _NavItem(
            tooltip: 'Moments',
            assetIconPath: AppNavAssets.momentsIcon,
            selected: selectedIndex == AppNavDestinations.momentsIndex,
            showDot: false,
            onTap: () =>
                onDestinationSelected(AppNavDestinations.momentsIndex),
          ),
        ),
        if (showVipCenter)
          Expanded(
            child: _NavItem(
              tooltip: 'VIP',
              assetIconPath: AppNavAssets.vipIcon,
              iconSize: AppNavDestinations.vipNavIconSize,
              iconSizeSelected: AppNavDestinations.vipNavIconSizeSelected,
              iconHitSize: AppNavDestinations.vipNavIconHitSize,
              selected: selectedIndex == AppNavDestinations.centerIndex,
              showDot: false,
              onTap: () =>
                  onDestinationSelected(AppNavDestinations.centerIndex),
            ),
          )
        else
          Expanded(
            child: _NavItem(
              tooltip: 'Recent',
              icon: Icons.history_outlined,
              selectedIcon: Icons.history,
              selected: selectedIndex == AppNavDestinations.centerIndex,
              showDot: false,
              onTap: () =>
                  onDestinationSelected(AppNavDestinations.centerIndex),
            ),
          ),
        Expanded(
          child: _NavItem(
            tooltip: 'Chats',
            assetIconPath: AppNavAssets.chatsIcon,
            selected: selectedIndex == AppNavDestinations.chatIndex,
            showDot: unreadCount > 0,
            onTap: () => onDestinationSelected(AppNavDestinations.chatIndex),
          ),
        ),
        Expanded(
          child: _NavItem(
            tooltip: 'Profile',
            assetIconPath: AppNavAssets.profileIcon,
            selected: selectedIndex == AppNavDestinations.profileIndex,
            showDot: false,
            onTap: () =>
                onDestinationSelected(AppNavDestinations.profileIndex),
          ),
        ),
      ],
    );

    return SizedBox(
      height: barStripHeight,
      child: AppNavBarBackground(
        clipper: const AppNavBarFlatClipper(),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: navRow,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String tooltip;
  final IconData? icon;
  final IconData? selectedIcon;
  final String? assetIconPath;
  final bool selected;
  final bool showDot;
  final VoidCallback onTap;
  final double? iconSize;
  final double? iconSizeSelected;
  final double? iconHitSize;

  const _NavItem({
    required this.tooltip,
    this.icon,
    this.selectedIcon,
    this.assetIconPath,
    this.iconSize,
    this.iconSizeSelected,
    this.iconHitSize,
    required this.selected,
    required this.showDot,
    required this.onTap,
  }) : assert(
          assetIconPath != null || (icon != null && selectedIcon != null),
          'Provide assetIconPath or both icon and selectedIcon',
        );

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: AppBrandGradients.accountMenuIconTint.withValues(alpha: 0.12),
          highlightColor:
              AppBrandGradients.accountMenuIconTint.withValues(alpha: 0.08),
          child: SizedBox(
            height: double.infinity,
            child: Center(
              child: assetIconPath != null
                  ? _NavAssetIcon(
                      assetPath: assetIconPath!,
                      selected: selected,
                      showDot: showDot,
                      iconSize: iconSize,
                      iconSizeSelected: iconSizeSelected,
                      hitSize: iconHitSize,
                    )
                  : _NavIcon(
                      icon: selected ? selectedIcon! : icon!,
                      selected: selected,
                      showDot: showDot,
                      iconSize: iconSize,
                      iconSizeSelected: iconSizeSelected,
                      hitSize: iconHitSize,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavAssetIcon extends StatelessWidget {
  final String assetPath;
  final bool selected;
  final bool showDot;
  final double? iconSize;
  final double? iconSizeSelected;
  final double? hitSize;

  const _NavAssetIcon({
    required this.assetPath,
    required this.selected,
    this.showDot = false,
    this.iconSize,
    this.iconSizeSelected,
    this.hitSize,
  });

  @override
  Widget build(BuildContext context) {
    final size = selected
        ? (iconSizeSelected ?? AppNavDestinations.navIconSizeSelected)
        : (iconSize ?? AppNavDestinations.navIconSize);
    final hit = hitSize ?? AppNavDestinations.navIconHitSize;

    return SizedBox(
      width: hit,
      height: hit,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.06 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: Opacity(
              opacity: selected ? 1.0 : 0.78,
              child: Image.asset(
                assetPath,
                width: size,
                height: size,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
              ),
            ),
          ),
          if (showDot)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4081),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final bool showDot;
  final double? iconSize;
  final double? iconSizeSelected;
  final double? hitSize;

  const _NavIcon({
    required this.icon,
    required this.selected,
    required this.showDot,
    this.iconSize,
    this.iconSizeSelected,
    this.hitSize,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = selected
        ? AppBrandGradients.accountMenuIconTint
        : AppBrandGradients.accountMenuIconTint.withValues(alpha: 0.55);
    final size = selected
        ? (iconSizeSelected ?? AppNavDestinations.navIconSizeSelected)
        : (iconSize ?? AppNavDestinations.navIconSize);
    final hit = hitSize ?? AppNavDestinations.navIconHitSize;

    return SizedBox(
      width: hit,
      height: hit,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(icon, size: size, color: iconColor),
          if (showDot)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4081),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

