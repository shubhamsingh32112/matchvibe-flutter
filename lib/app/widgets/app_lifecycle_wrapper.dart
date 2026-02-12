import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/creator/providers/creator_dashboard_provider.dart';
import '../../features/creator/providers/creator_status_provider.dart';
import '../../features/video/controllers/call_connection_controller.dart';
import '../../features/home/providers/home_provider.dart';
import '../../features/video/services/call_navigation_service.dart';

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
  static const String _hasShownPopupKey = 'has_shown_creator_popup';
  bool _hasShownPopup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndShowPopup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
        // App opened — reset popup flag and check if we should show popup
        _hasShownPopup = false;
        _checkAndShowPopup();
        // Refresh creator dashboard so earnings/tasks are up-to-date
        debugPrint(
            '📱 [APP LIFECYCLE] App resumed — refreshing creator dashboard');
        ref.invalidate(creatorDashboardProvider);
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App backgrounded — set creator offline ONLY if no active call.
      // 🔥 CRITICAL: Creators must stay online during calls.
      // Android / iOS can trigger paused / inactive during calls
      // (audio routing, PiP, etc.)
      if (user != null &&
          (user.role == 'creator' || user.role == 'admin')) {
        if (!hasActiveCall) {
          debugPrint(
              '📱 [APP LIFECYCLE] App backgrounded, setting creator offline');
          ref
              .read(creatorStatusProvider.notifier)
              .setStatus(CreatorStatus.offline);
        } else {
          debugPrint(
              '📱 [APP LIFECYCLE] App backgrounded but active call exists — staying online');
        }
      }
    } else if (state == AppLifecycleState.detached) {
      // App closed — clear popup flag for next session
      if (user != null &&
          (user.role == 'creator' || user.role == 'admin')) {
        _clearPopupFlag();
      }
    }
  }

  // 🔥 CRITICAL: Navigation removed from lifecycle handler.
  // Navigation is now handled by CallConnectionController (single authority).
  // Lifecycle only logs / refreshes data — prevents race conditions.

  Future<void> _clearPopupFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_hasShownPopupKey);
    } catch (e) {
      debugPrint('⚠️  [APP LIFECYCLE] Failed to clear popup flag: $e');
    }
  }

  Future<void> _checkAndShowPopup() async {
    if (_hasShownPopup) return;

    final authState = ref.read(authProvider);
    final user = authState.user;

    // Only show popup for creators
    if (user == null ||
        (user.role != 'creator' && user.role != 'admin')) {
      return;
    }

    // Wait a bit for the app to fully load
    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;

    // Check current status
    final currentStatus = ref.read(creatorStatusProvider);
    if (currentStatus == CreatorStatus.online) {
      // Already online, don't show popup
      _hasShownPopup = true;
      return;
    }

    // Show popup
    _hasShownPopup = true;

    if (!mounted) return;

    _showGoOnlineDialog();
  }

  void _showGoOnlineDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Go Online?'),
        content: const Text(
          'You are currently offline. Would you like to go online so users can see you on the homepage?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Set creator online
              ref
                  .read(creatorStatusProvider.notifier)
                  .setStatus(CreatorStatus.online);
            },
            child: const Text('Go Online'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
