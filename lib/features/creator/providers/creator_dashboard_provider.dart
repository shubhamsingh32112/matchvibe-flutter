import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/creator_dashboard_model.dart';
import '../services/creator_dashboard_service.dart';
import '../../wallet/models/earnings_model.dart';
import '../models/creator_task_model.dart';
import '../../auth/providers/auth_provider.dart';

// ── Service provider ──────────────────────────────────────────────────────
final creatorDashboardServiceProvider = Provider<CreatorDashboardService>(
  (ref) => CreatorDashboardService(),
);

// ── Main dashboard provider (the single source of truth) ──────────────────
/// Fetches consolidated creator data from GET /creator/dashboard.
///
/// Invalidate this provider to force a re-fetch:
/// ```dart
/// ref.invalidate(creatorDashboardProvider);
/// ```
///
/// This is automatically invalidated when:
/// - `creator:data_updated` socket event fires (call settled / task claimed)
/// - App resumes from background
/// - Manual pull-to-refresh
final creatorDashboardProvider = FutureProvider<CreatorDashboard>((ref) async {
  final service = ref.read(creatorDashboardServiceProvider);
  debugPrint('📊 [PROVIDER] Fetching creator dashboard...');
  return await service.getCreatorDashboard();
});

// ── Derived providers for convenience ─────────────────────────────────────

/// Earnings data extracted from the dashboard.
/// Screens that only need earnings can watch this.
final dashboardEarningsProvider = FutureProvider<CreatorEarnings>((ref) async {
  final dashboard = await ref.watch(creatorDashboardProvider.future);
  return dashboard.earnings;
});

/// Tasks data extracted from the dashboard.
/// Screens that only need tasks can watch this.
final dashboardTasksProvider = FutureProvider<CreatorTasksResponse>((ref) async {
  final dashboard = await ref.watch(creatorDashboardProvider.future);
  return dashboard.tasks;
});

/// Today's earnings data extracted from the dashboard.
/// Shows coins earned, calls, and minutes for the current daily period.
final dashboardTodayEarningsProvider = FutureProvider<TodayEarnings>((ref) async {
  final dashboard = await ref.watch(creatorDashboardProvider.future);
  return dashboard.todayEarnings;
});

/// Creator's current coin balance.
/// 🔥 OPTIMIZED: Uses auth state for instant updates (via socket events)
/// Falls back to dashboard API if auth state not available
final dashboardCoinsProvider = Provider<int>((ref) {
  // 🔥 FIX: Use auth state for instant coin updates (updated via socket events)
  // This provides instant UI updates without waiting for API calls
  final authState = ref.watch(authProvider);
  final authCoins = authState.user?.coins;
  
  if (authCoins != null) {
    // Use auth state coins (updated instantly via socket events)
    return authCoins;
  }
  
  // Fallback: Try to get from dashboard if available (shouldn't happen in normal flow)
  final dashboardAsync = ref.watch(creatorDashboardProvider);
  return dashboardAsync.when(
    data: (dashboard) => dashboard.coins,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
