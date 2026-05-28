import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/chat/providers/stream_chat_provider.dart';
import '../../features/creator/providers/creator_dashboard_provider.dart';
import '../../features/creator/providers/creator_status_provider.dart';
import '../../features/creator/providers/creator_presence_orchestrator_provider.dart';
import '../../features/creator/widgets/creator_status_label.dart';
import '../../features/recent/providers/recent_provider.dart';
import '../../features/video/providers/call_billing_provider.dart';
import '../../features/video/providers/call_billing_selectors.dart';
import '../../shared/styles/app_brand_styles.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/gem_icon.dart';
import '../../shared/widgets/brand_app_chrome.dart';

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;
  final int selectedIndex;
  final PreferredSizeWidget? appBar;

  /// When true (Account tab only), hides the app bar and full-width gradient
  /// wrapper so the child can paint the menu-style header and body.
  final bool accountMenuStyle;

  const MainLayout({
    super.key,
    required this.child,
    required this.selectedIndex,
    this.appBar,
    this.accountMenuStyle = false,
  });

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        final role = ref.read(authProvider).user?.role;
        if (role == 'creator' || role == 'admin') {
          unawaited(
            ref
                .read(creatorPresenceOrchestratorProvider)
                .refreshPresence(reason: 'home_tab_tap'),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    final userRole = ref.watch(authProvider.select((s) => s.user?.role));
    final isCreator = userRole == 'creator' || userRole == 'admin';
    final isRegularUser = userRole == 'user';
    final isHomePage = widget.selectedIndex == 0;

    // Refresh user data + call history when billing settles
    // 🔥 OPTIMIZED: Socket events (coins_updated, creator:data_updated) handle most updates instantly
    // This listener is a fallback safety net for edge cases
    ref.listen<CallBillingState>(callBillingProvider, (prev, next) {
      if (prev?.isBillingSettled != true && next.isBillingSettled) {
        // 🔥 FIX: Only refresh if socket events haven't already updated (fallback)
        // Socket events fire immediately after settlement, so this is rarely needed
        // But keep it as a safety net for edge cases (socket disconnected, etc.)
        ref.read(authProvider.notifier).refreshUser();
        ref.invalidate(recentCallsProvider); // Refresh recent calls list
        // Also refresh creator dashboard if user is a creator (for earnings/stats)
        // Note: Coins are updated instantly via socket events, so this mainly updates earnings/stats
        final role = ref.read(authProvider).user?.role;
        if (role == 'creator' || role == 'admin') {
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

    final scaffold = Scaffold(
      backgroundColor: widget.accountMenuStyle
          ? scheme.surface
          : AppBrandGradients.accountMenuPageBackground,
      appBar:
          widget.appBar ??
          (widget.accountMenuStyle
              ? null
              : buildBrandAppBar(
                  context,
                  title: AppConstants.appName,
                  actions: [
                    if (showStatusToggle) ...[
                      Consumer(
                        builder: (context, ref, child) {
                          final status = ref.watch(creatorStatusProvider);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: CreatorStatusLabel(
                              status: status,
                              compact: true,
                              useAppBarColors: true,
                            ),
                          );
                        },
                      ),
                    ],
                    if (isHomePage && isRegularUser)
                      IconButton(
                        tooltip: 'Favorite creators',
                        icon: const Icon(Icons.favorite_border),
                        onPressed: () => context.push('/home/favorites'),
                      ),
                    _MainLayoutCoinChip(isCreator: isCreator),
                  ],
                )),
      body: widget.accountMenuStyle
          ? widget.child
          : ColoredBox(
              color: AppBrandGradients.accountMenuPageBackground,
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
          const _MainLayoutChatNavDestination(),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );

    if (widget.accountMenuStyle) {
      return scaffold;
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: scaffold,
    );
  }
}

/// Coin balance chip — watches coins/loading/billing only, not full [authProvider].
class _MainLayoutCoinChip extends ConsumerWidget {
  final bool isCreator;

  const _MainLayoutCoinChip({required this.isCreator});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authCoins = ref.watch(
      authProvider.select((s) => (s.user?.coins ?? 0, s.isLoading)),
    );
    final billingSlice = ref.watch(
      callBillingProvider.select((b) => (b.runtimeState, b.userCoins)),
    );
    final useLiveCoins = !isCreator &&
        (billingSlice.$1 == BillingRuntimeState.active ||
            billingSlice.$1 == BillingRuntimeState.recovering);
    final coins = useLiveCoins
        ? billingSlice.$2
        : authCoins.$1;
    final isLoading = authCoins.$2;

    return InkWell(
      onTap: () {
        final path = GoRouter.of(
          context,
        ).routeInformationProvider.value.uri.path;
        if (path == '/wallet') {
          ref.read(authProvider.notifier).refreshUser();
          return;
        }
        context.push('/wallet');
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const GemIcon(size: 20),
            const SizedBox(width: 4),
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: LoadingIndicator(size: 16, color: Colors.white),
              )
            else
              Text(
                coins.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Chat tab badge — watches unread count only.
class _MainLayoutChatNavDestination extends ConsumerWidget {
  const _MainLayoutChatNavDestination();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(
      chatUnreadCountProvider.select((a) => a.valueOrNull ?? 0),
    );

    return NavigationDestination(
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
    );
  }
}
