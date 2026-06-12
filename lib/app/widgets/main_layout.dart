import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/creator/providers/creator_dashboard_provider.dart';
import '../../features/creator/providers/creator_presence_orchestrator_provider.dart';
import '../../features/home/providers/home_provider.dart';
import '../../features/recent/providers/recent_provider.dart';
import '../../features/video/providers/call_billing_provider.dart';
import '../../features/video/providers/call_billing_selectors.dart';
import '../../shared/styles/app_brand_styles.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/gem_icon.dart';
import '../../shared/widgets/brand_app_chrome.dart';
import 'app_bottom_nav_bar.dart';
import 'app_nav_destinations.dart';
import 'app_nav_index.dart';

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;
  final int selectedIndex;
  final PreferredSizeWidget? appBar;

  /// When true (Account tab only), hides the app bar and full-width gradient
  /// wrapper so the child can paint the menu-style header and body.
  final bool accountMenuStyle;

  /// When true (VIP tab), hides the default app bar and light page wrapper so
  /// the child can paint the dark VIP marketing layout.
  final bool vipPageStyle;

  const MainLayout({
    super.key,
    required this.child,
    required this.selectedIndex,
    this.appBar,
    this.accountMenuStyle = false,
    this.vipPageStyle = false,
  });

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  void _onItemTapped(int index) {
    final role = ref.read(authProvider).user?.role;
    final tabs = ref.read(appNavTabsProvider);
    if (tabs[index].id == AppNavTabId.home) {
      if (AppNavDestinations.isCreatorOrAdmin(role)) {
        unawaited(
          ref
              .read(creatorPresenceOrchestratorProvider)
              .refreshPresence(reason: 'home_tab_tap'),
        );
      } else if (role == 'user') {
        unawaited(
          resyncUserHomeFeedPresenceAndOrder(
            ref,
            reason: 'home_tab_tap',
            bypassThrottle: true,
          ),
        );
      }
    }
    context.go(AppNavDestinations.routeForIndex(tabs, index));
  }

  @override
  Widget build(BuildContext context) {
    final userRole = ref.watch(authProvider.select((s) => s.user?.role));
    final isCreator = AppNavDestinations.isCreatorOrAdmin(userRole);
    final isRegularUser = userRole == 'user';
    final tabs = ref.watch(appNavTabsProvider);
    final isHomePage = widget.selectedIndex >= 0 &&
        widget.selectedIndex < tabs.length &&
        tabs[widget.selectedIndex].id == AppNavTabId.home;

    ref.listen<CallBillingState>(callBillingProvider, (prev, next) {
      if (prev?.isBillingSettled != true && next.isBillingSettled) {
        ref.read(authProvider.notifier).refreshUser();
        ref.invalidate(recentCallsProvider);
        final role = ref.read(authProvider).user?.role;
        if (AppNavDestinations.isCreatorOrAdmin(role)) {
          ref.invalidate(creatorDashboardProvider);
        }
        Future.delayed(const Duration(seconds: 2), () {
          ref.read(callBillingProvider.notifier).reset();
        });
      }
    });

    final scheme = Theme.of(context).colorScheme;

    final customPageStyle = widget.accountMenuStyle || widget.vipPageStyle;

    final scaffold = Scaffold(
      extendBody: false,
      backgroundColor: widget.vipPageStyle
          ? const Color(0xFF0A0618)
          : widget.accountMenuStyle
          ? scheme.surface
          : AppBrandGradients.accountMenuPageBackground,
      appBar:
          widget.appBar ??
          (customPageStyle
              ? null
              : buildBrandAppBar(
                  context,
                  title: AppConstants.appName,
                  actions: [
                    if (isHomePage && isRegularUser)
                      IconButton(
                        tooltip: 'Favorite creators',
                        icon: const Icon(Icons.favorite_border),
                        onPressed: () => context.push('/home/favorites'),
                      ),
                    _MainLayoutCoinChip(isCreator: isCreator),
                  ],
                )),
      body: customPageStyle
          ? widget.child
          : ColoredBox(
              color: AppBrandGradients.accountMenuPageBackground,
              child: widget.child,
            ),
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: widget.selectedIndex,
        onDestinationSelected: _onItemTapped,
      ),
    );

    if (customPageStyle) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: scaffold,
      );
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
    final coins = useLiveCoins ? billingSlice.$2 : authCoins.$1;
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
            const GemIcon(size: 30),
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
