import 'package:flutter/material.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../router/app_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/creator/providers/creator_dashboard_provider.dart';
import '../../features/video/controllers/call_connection_controller.dart';
import '../../features/home/providers/home_provider.dart';
import '../../shared/widgets/coin_purchase_popup.dart';

/// Widget that wraps the app and handles lifecycle events.
///
/// - Shows popup for creators when app opens.
/// - Sets creator offline when app goes to background.
///
/// 🔥 CRITICAL: All active-call checks now use [CallConnectionController]
/// (the single source of truth), NOT `streamVideo.state.activeCall`.
class AppLifecycleWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const AppLifecycleWrapper({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AppLifecycleWrapper> createState() =>
      _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends ConsumerState<AppLifecycleWrapper>
    with WidgetsBindingObserver {
  static const String _lastHandledPaymentDeepLinkKey = 'last_handled_payment_deep_link';
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _deepLinkSub;
  bool _coinPopupShownThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureCreatorOnline();
    });
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    try {
      _appLinks = AppLinks();
      final initialUri = await _appLinks!.getInitialLink();
      if (initialUri != null) {
        await _handleIncomingDeepLink(initialUri);
      }

      _deepLinkSub = _appLinks!.uriLinkStream.listen(
        (uri) {
          _handleIncomingDeepLink(uri);
        },
        onError: (Object err) {
          debugPrint('⚠️  [APP LINKS] Deep link stream error: $err');
        },
      );
    } catch (e) {
      debugPrint('⚠️  [APP LINKS] Failed to initialize app links: $e');
    }
  }

  Future<void> _handleIncomingDeepLink(Uri uri) async {
    if (!mounted) return;

    if (uri.scheme != 'zztherapy') return;
    if (uri.host != 'wallet') return;

    final paymentStatus = uri.queryParameters['payment'];
    if (paymentStatus == null || paymentStatus.isEmpty) return;

    if (!await _shouldHandlePaymentDeepLink(uri, paymentStatus)) {
      debugPrint('⏭️  [APP LINKS] Ignoring duplicate payment deep link: $uri');
      return;
    }

    final coinsAdded = int.tryParse(uri.queryParameters['coinsAdded'] ?? '0') ?? 0;
    final deepLinkMessage = uri.queryParameters['message'];

    if (paymentStatus == 'success') {
      ref.read(authProvider.notifier).refreshUser();
      final params = <String, String>{
        'payment': 'success',
        'coinsAdded': coinsAdded.toString(),
      };
      if (deepLinkMessage != null && deepLinkMessage.isNotEmpty) {
        params['message'] = deepLinkMessage;
      }
      appRouter.go(Uri(
        path: '/wallet/payment-status',
        queryParameters: params,
      ).toString());
      return;
    }

    if (paymentStatus == 'failed') {
      final params = <String, String>{
        'payment': 'failed',
      };
      if (deepLinkMessage != null && deepLinkMessage.isNotEmpty) {
        params['message'] = deepLinkMessage;
      } else {
        params['message'] = 'Payment failed or cancelled. Please try again.';
      }
      appRouter.go(Uri(
        path: '/wallet/payment-status',
        queryParameters: params,
      ).toString());
    }
  }

  Future<bool> _shouldHandlePaymentDeepLink(Uri uri, String paymentStatus) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orderId = uri.queryParameters['orderId'];
      final dedupeId = (orderId != null && orderId.isNotEmpty)
          ? '$paymentStatus:$orderId'
          : uri.toString();

      final lastHandled = prefs.getString(_lastHandledPaymentDeepLinkKey);
      if (lastHandled == dedupeId) {
        return false;
      }

      await prefs.setString(_lastHandledPaymentDeepLinkKey, dedupeId);
      return true;
    } catch (e) {
      debugPrint('⚠️  [APP LINKS] Failed to persist deep link dedupe state: $e');
      // Fail open so genuine payments are not blocked.
      return true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final authState = ref.read(authProvider);
    final user = authState.user;

    // ── Controller-aware active-call check ──
    final controllerPhase =
        ref.read(callConnectionControllerProvider).phase;
    final hasActiveCall =
        controllerPhase != CallConnectionPhase.idle &&
            controllerPhase != CallConnectionPhase.failed;

    if (state == AppLifecycleState.resumed) {
      // 🔥 CRITICAL: DO NOT navigate from lifecycle — causes race conditions.
      // Only log / refresh data.  Navigation is owned by CallConnectionController.
      if (hasActiveCall) {
        debugPrint(
            '📱 [APP LIFECYCLE] App resumed with active call (phase: $controllerPhase)');
        debugPrint(
            '   Call screen should already be visible — not navigating');
      }

      // Refresh home feed when app resumes (so users see newly online creators)
      if (user != null && user.role == 'user') {
        debugPrint(
            '📱 [APP LIFECYCLE] App resumed — refreshing home feed for user');
        ref.invalidate(homeFeedProvider);
      }

      // Only handle lifecycle for creators
      if (user != null &&
          (user.role == 'creator' || user.role == 'admin')) {
        // 🔥 AUTOMATIC: Socket connection automatically sets creator online
        // No manual status setting needed - socket handles it
        // Refresh creator dashboard so earnings/tasks are up-to-date
        debugPrint(
            '📱 [APP LIFECYCLE] App resumed — socket will auto-set creator online');
        ref.invalidate(creatorDashboardProvider);
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Keep creators online while app is alive, including background.
      // Socket connection remains active, so creator stays online
      if (user != null &&
          (user.role == 'creator' || user.role == 'admin')) {
        debugPrint(
            '📱 [APP LIFECYCLE] App backgrounded — socket keeps creator online');
      }
    } else if (state == AppLifecycleState.detached) {
      // App closed — socket disconnect will automatically mark creator offline
      // Backend socket handler handles this automatically
      if (user != null &&
          (user.role == 'creator' || user.role == 'admin')) {
        debugPrint(
            '📱 [APP LIFECYCLE] App closed — socket disconnect will auto-set creator offline');
      }
    }
  }

  // 🔥 CRITICAL: Navigation removed from lifecycle handler.
  // Navigation is now handled by CallConnectionController (single authority).
  // Lifecycle only logs / refreshes data — prevents race conditions.

  Future<void> _ensureCreatorOnline() async {
    final authState = ref.read(authProvider);
    final user = authState.user;

    // Only creators/admins have availability state.
    if (user == null ||
        (user.role != 'creator' && user.role != 'admin')) {
      return;
    }

    // 🔥 AUTOMATIC: Socket connection automatically handles online/offline
    // When socket connects, backend sets creator online automatically
    // When socket disconnects, backend sets creator offline automatically
    // No manual status setting needed
    debugPrint('✅ [APP LIFECYCLE] Socket connection handles creator status automatically');
  }

  /// Show coin purchase popup once per app session when app opens.
  /// Only for regular users, not creators or admins.
  void _showCoinPurchasePopupOnAppOpen() {
    if (_coinPopupShownThisSession) return;
    if (!mounted) return;

    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated) return;

    final user = authState.user;
    // Only show for regular users, not creators or admins
    if (user == null || user.role != 'user') return;

    // Mark as shown immediately to prevent duplicate displays
    _coinPopupShownThisSession = true;

    // Show popup immediately (no delay)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = this.context;
      if (!context.mounted) return;
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const CoinPurchaseBottomSheet(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check initial auth state (in case user is already authenticated when app opens)
    final authState = ref.watch(authProvider);
    if (authState.isAuthenticated && 
        !_coinPopupShownThisSession && 
        authState.user != null && 
        authState.user!.role == 'user') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCoinPurchasePopupOnAppOpen();
      });
    }
    
    ref.listen<AuthState>(authProvider, (prev, next) {
      final user = next.user;
      final isCreator =
          user != null && (user.role == 'creator' || user.role == 'admin');
      if (next.isAuthenticated && isCreator) {
        _ensureCreatorOnline();
      }
      
      // Show coin purchase popup once per app session when user becomes authenticated
      // (only if not already shown in this session and user is a regular user)
      // Only trigger on state change (prev != next), not on initial build
      if (prev != null && 
          next.isAuthenticated && 
          !_coinPopupShownThisSession && 
          user != null && 
          user.role == 'user') {
        _showCoinPurchasePopupOnAppOpen();
      }
    });

    return widget.child;
  }
}
