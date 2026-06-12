import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/chat/providers/stream_chat_provider.dart';
import '../../shared/styles/app_brand_styles.dart';
import 'app_nav_bar_shape.dart';
import 'app_nav_destinations.dart';
import 'app_nav_index.dart';

class AppBottomNavBar extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const AppBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(appNavTabsProvider);
    final unreadCount = ref.watch(
      chatUnreadCountProvider.select((a) => a.valueOrNull ?? 0),
    );
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final barStripHeight = AppNavDestinations.barHeight + bottomInset;

    final navRow = Row(
      children: [
        for (var i = 0; i < tabs.length; i++)
          Expanded(
            child: _buildNavItem(
              tab: tabs[i],
              index: i,
              selected: selectedIndex == i,
              showDot: tabs[i].id == AppNavTabId.chat && unreadCount > 0,
              onTap: () => onDestinationSelected(i),
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

  Widget _buildNavItem({
    required AppNavTab tab,
    required int index,
    required bool selected,
    required bool showDot,
    required VoidCallback onTap,
  }) {
    return _NavItem(
      tooltip: tab.tooltip,
      assetIconPath: tab.assetIconPath,
      icon: tab.icon,
      selectedIcon: tab.selectedIcon,
      iconSize: tab.iconSize,
      iconSizeSelected: tab.iconSizeSelected,
      iconHitSize: tab.iconHitSize,
      selected: selected,
      showDot: showDot,
      onTap: onTap,
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
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppBrandGradients.accountMenuIconTint,
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
            child: Icon(
              icon,
              size: size,
              color: selected
                  ? AppBrandGradients.accountMenuIconTint
                  : AppBrandGradients.accountMenuIconTint.withValues(alpha: 0.78),
            ),
          ),
          if (showDot)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppBrandGradients.accountMenuIconTint,
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
