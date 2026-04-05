import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/chat/providers/stream_chat_provider.dart';
import '../../features/creator/providers/creator_dashboard_provider.dart';
import '../../features/creator/providers/creator_status_provider.dart';
import '../../features/recent/providers/recent_provider.dart';
import '../../features/video/providers/call_billing_provider.dart';
import '../../features/wallet/screens/wallet_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/styles/app_brand_styles.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/gem_icon.dart';
import '../../shared/widgets/app_modal_bottom_sheet.dart';

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;
  final int selectedIndex;

  /// When true (Account tab only), hides the app bar and full-width gradient
  /// wrapper so the child can paint the menu-style header and body.
  final bool accountMenuStyle;

  const MainLayout({
    super.key,
    required this.child,
    required this.selectedIndex,
    this.accountMenuStyle = false,
  });

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/recent');
        break;
      case 2:
        context.go('/chat-list');
        break;
      case 3:
        context.go('/account');
        break;
    }
  }

  void _showWalletBottomSheet(BuildContext context) {
    showAppModalBottomSheet(
      context: context,
      builder: (context) => const WalletBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final unreadCountAsync = ref.watch(chatUnreadCountProvider);
    final billingState = ref.watch(callBillingProvider);
    final unreadCount = unreadCountAsync.valueOrNull ?? 0;
    final isCreator = authState.user?.role == 'creator' || authState.user?.role == 'admin';
    final isRegularUser = authState.user?.role == 'user';
    final isHomePage = widget.selectedIndex == 0;

    // During an active call, show live Redis coins; otherwise show MongoDB coins
    final coins = billingState.isActive && !isCreator
        ? billingState.userCoins
        : (authState.user?.coins ?? 0);

    // Refresh user data + call history when billing settles
    // 🔥 OPTIMIZED: Socket events (coins_updated, creator:data_updated) handle most updates instantly
    // This listener is a fallback safety net for edge cases
    ref.listen<CallBillingState>(callBillingProvider, (prev, next) {
      if (prev?.settled != true && next.settled) {
        // 🔥 FIX: Only refresh if socket events haven't already updated (fallback)
        // Socket events fire immediately after settlement, so this is rarely needed
        // But keep it as a safety net for edge cases (socket disconnected, etc.)
        ref.read(authProvider.notifier).refreshUser();
        ref.invalidate(recentCallsProvider); // Refresh recent calls list
        // Also refresh creator dashboard if user is a creator (for earnings/stats)
        // Note: Coins are updated instantly via socket events, so this mainly updates earnings/stats
        if (isCreator) {
          ref.invalidate(creatorDashboardProvider);
        }
        // Reset billing state after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          ref.read(callBillingProvider.notifier).reset();
        });
      }
    });
    
    // Show online/offline toggle only for creators on homepage
    final showStatusToggle = isCreator && isHomePage;

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: widget.accountMenuStyle
          ? null
          : AppBar(
          title: Text(
            AppConstants.appName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            // Online/Offline toggle for creators on homepage
            if (showStatusToggle) ...[
              Consumer(
                builder: (context, ref, child) {
                  final status = ref.watch(creatorStatusProvider);
                  final isOnline = status == CreatorStatus.online;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        // Status indicator (read-only, no toggle)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                isOnline ? AppPalette.success : scheme.outline,
                            border: Border.all(
                              color: scheme.surface,
                              width: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Status text (read-only)
                        Text(
                          isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: isOnline
                                ? AppPalette.success
                                : AppPalette.subtitle,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            // Favorites shortcut for users on homepage only
            if (isHomePage && isRegularUser)
              IconButton(
                tooltip: 'Favorite creators',
                icon: const Icon(Icons.favorite_border),
                onPressed: () => context.push('/home/favorites'),
              ),
            // Coins display - Clickable to open wallet bottom sheet
            InkWell(
              onTap: () => _showWalletBottomSheet(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const GemIcon(size: 20),
                    const SizedBox(width: 4),
                    if (authState.isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: LoadingIndicator(size: 16),
                      )
                    else
                      Text(
                        coins.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      body: widget.accountMenuStyle
          ? widget.child
          : Container(
              decoration: const BoxDecoration(
                gradient: AppBrandGradients.appBackground,
              ),
              child: widget.child,
            ),
      bottomNavigationBar: NavigationBar(
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent,
          selectedIndex: widget.selectedIndex,
          onDestinationSelected: _onItemTapped,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'Recent',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: unreadCount > 0,
                label: Text(unreadCount.toString()),
                child: const Icon(Icons.chat_bubble_outline),
              ),
              selectedIcon: Badge(
                isLabelVisible: unreadCount > 0,
                label: Text(unreadCount.toString()),
                child: const Icon(Icons.chat_bubble),
              ),
              label: 'Chat',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Account',
            ),
          ],
        ),
    );
  }
}
