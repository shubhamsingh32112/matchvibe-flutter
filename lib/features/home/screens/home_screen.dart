import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../app/widgets/main_layout.dart';
import '../../../shared/widgets/skeleton_card.dart';
import '../../../shared/widgets/welcome_dialog.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/models/creator_model.dart';
import '../../../shared/models/profile_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/welcome_service.dart';
import '../../../core/services/permission_prompt_service.dart';
import '../providers/home_provider.dart';
// 🔥 REMOVED: creator_presence_provider.dart - replaced by Socket.IO availability
import '../widgets/home_user_grid_card.dart';
import '../../creator/providers/creator_task_provider.dart';
import '../../creator/models/creator_task_model.dart';
import '../../wallet/providers/earnings_provider.dart';
import '../../creator/providers/creator_status_provider.dart';
import '../../video/services/permission_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _welcomeDialogShown = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // ✅ DO NOT use ref.read() or ref.watch() in initState()
    // ✅ DO NOT call async methods that use context here
    // Logic moved to didChangeDependencies() where ProviderScope is available
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // ✅ SAFE: ProviderScope is now available
    // ✅ Run initialization logic only once
    if (_initialized) return;
    _initialized = true;
    
    // 🔥 REMOVED: Stream presence listener
    // Availability is now handled by Socket.IO via creatorStatusProvider
    // Individual cards watch their own availability status
    
    // Schedule async operations after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      _checkAndShowWelcomeDialog();
      _checkAndRequestVideoPermissions();
    });
  }

  Future<void> _checkAndShowWelcomeDialog() async {
    // Wait for the first frame to ensure context is available
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return; // ✅ Guard: Check mounted before any context/ref usage
    
    // Check if user is authenticated
    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated) {
      return; // Don't show welcome dialog if not authenticated
    }
    
    // Check if user has seen the welcome dialog
    final hasSeen = await WelcomeService.hasSeenWelcome();
    
    if (!mounted) return; // ✅ Guard: Check mounted after async operation
    
    if (!hasSeen && !_welcomeDialogShown) {
      _welcomeDialogShown = true;
      _showWelcomeDialog();
    }
  }

  void _showWelcomeDialog() {
    if (!mounted) return; // ✅ Guard: Never show dialog if widget is disposed
    
    showDialog(
      context: context,
      barrierDismissible: false, // User must click "I agree"
      builder: (context) => WelcomeDialog(
        onAgree: () async {
          // Mark as seen
          await WelcomeService.markWelcomeAsSeen();
          if (mounted && context.mounted) { // ✅ Guard: Check both mounted and context.mounted
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  /// Check and request video permissions for users
  /// Only shows dialog once (persisted across sessions) if permissions are not granted
  /// 
  /// 🔥 CRITICAL: Uses persistent flag to prevent showing on every rebuild
  /// Prevents dialog spam on hot reloads, theme changes, navigation back, etc.
  Future<void> _checkAndRequestVideoPermissions() async {
    // Wait for auth state to be available
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return; // ✅ Guard: Check mounted before any context/ref usage
    
    final authState = ref.read(authProvider);
    final user = authState.user;
    
    // Only request permissions for regular users (they can make video calls)
    if (user == null || user.role != 'user') {
      return;
    }
    
    // Check if permissions are already granted
    final hasPermissions = await PermissionService.hasCameraAndMicrophonePermissions();
    
    if (!mounted) return; // ✅ Guard: Check mounted after async operation
    
    if (hasPermissions) {
      debugPrint('✅ [HOME] Camera and microphone permissions already granted');
      return;
    }
    
    // 🔥 CRITICAL: Check persistent flag (not session flag)
    // This prevents showing dialog on every rebuild/hot reload/navigation
    final hasShownPrompt = await PermissionPromptService.hasShownPermissionPrompt();
    
    if (!mounted) return; // ✅ Guard: Check mounted after async operation
    
    if (hasShownPrompt) {
      debugPrint('⏭️  [HOME] Permission prompt already shown (persisted)');
      return;
    }
    
    // Wait a bit more for UI to stabilize
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (!mounted) return; // ✅ Guard: Check mounted after async delay
    
    // Mark as shown BEFORE showing dialog (prevents race conditions)
    await PermissionPromptService.markPermissionPromptAsShown();
    
    if (!mounted) return; // ✅ Guard: Check mounted before showing dialog
    _showVideoPermissionDialog();
  }

  /// Show dialog requesting video permissions
  void _showVideoPermissionDialog() {
    if (!mounted) return; // ✅ Guard: Never show dialog if widget is disposed
    
    final scheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.videocam, color: scheme.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Enable Video Calls'),
            ),
          ],
        ),
        content: const Text(
          'To make video calls with creators, we need access to your camera and microphone. '
          'You can enable these permissions in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted && context.mounted) { // ✅ Guard: Check both mounted and context.mounted
                Navigator.of(context).pop();
              }
            },
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (mounted && context.mounted) { // ✅ Guard: Check before navigation
                Navigator.of(context).pop();
              }
              
              try {
                final granted = await PermissionService.ensureCameraAndMicrophonePermissions();
                
                if (!mounted) return; // ✅ Guard: Check mounted after async operation
                
                if (granted) {
                  if (mounted && context.mounted) { // ✅ Guard: Check before showing snackbar
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Permissions granted! You can now make video calls.'),
                        backgroundColor: scheme.primaryContainer,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } else {
                  if (mounted && context.mounted) { // ✅ Guard: Check before showing snackbar
                    // Permissions denied - show message about settings
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Permissions are required for video calls. Please enable them in app settings.',
                        ),
                        backgroundColor: scheme.errorContainer,
                        duration: const Duration(seconds: 4),
                        action: SnackBarAction(
                          label: 'Settings',
                          textColor: scheme.onErrorContainer,
                          onPressed: () async {
                            // Open app settings so user can enable permissions manually
                            await PermissionService.openAppSettings();
                          },
                        ),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (!mounted) return; // ✅ Guard: Check mounted after error
                
                if (mounted && context.mounted) { // ✅ Guard: Check before showing snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: scheme.errorContainer,
                    ),
                  );
                }
              }
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final homeFeedItems = ref.watch(homeFeedProvider); // Now a Provider, not FutureProvider
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isCreator = user?.role == 'creator' || user?.role == 'admin';
    final isRegularUser = user?.role == 'user';
    final scheme = Theme.of(context).colorScheme;

    // 🔥 REMOVED: Stream presence listener
    // Availability is now handled by Socket.IO via creatorStatusProvider

    return MainLayout(
        selectedIndex: 0,
        child: AppScaffold(
          padded: true,
          child: isCreator
            ? _CreatorTasksView()
            : _buildHomeFeedContent(homeFeedItems, isRegularUser, scheme, authState, isCreator),
      ),
    );
  }

  Widget _buildHomeFeedContent(List<dynamic> items, bool isRegularUser, ColorScheme scheme, AuthState authState, bool isCreator) {
    // Show loading state while creators are being fetched
    final creatorsAsync = ref.watch(creatorsProvider);
    final isLoading = creatorsAsync.isLoading;
    
    if (isLoading) {
      return GridView.builder(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.78,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => const SkeletonCard(),
      );
    }
    
    // Show empty state if no items
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(creatorsProvider);
          ref.invalidate(homeFeedProvider);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: EmptyState(
              icon: isCreator ? Icons.people_outline : Icons.person_outline,
              title: isCreator ? 'No users available' : 'No online creators available',
              message: isCreator ? 'Users will appear here when they join' : 'Creators will appear here when they go online',
            ),
          ),
        ),
      );
    }
    // Users-only: separate favorites from the rest (favorites are pinned at top)
    final List<CreatorModel> favoriteCreators = [];
    final List<CreatorModel> otherCreators = [];
    if (isRegularUser) {
      for (final item in items) {
        if (item is CreatorModel) {
          if (item.isFavorite) {
            favoriteCreators.add(item);
          } else {
            otherCreators.add(item);
          }
        }
      }
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Manual refresh - invalidate providers to force refetch
        debugPrint('🔄 [HOME] Manual refresh triggered');
        ref.invalidate(creatorsProvider);
        ref.invalidate(homeFeedProvider);
        // Wait a bit for the refresh to complete
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _OnlinePill(),
                    const Spacer(),
                    _CoinsPill(coins: authState.user?.coins ?? 0, isLoading: authState.isLoading),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  isRegularUser ? 'Creators (${items.length})' : 'Users (${items.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (isRegularUser && favoriteCreators.isNotEmpty) ...[
                  Text(
                    'Favourites (${favoriteCreators.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 210,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: favoriteCreators.length,
                      separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.md),
                      itemBuilder: (context, index) => SizedBox(
                        width: 170,
                        child: HomeUserGridCard(creator: favoriteCreators[index]),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: 0.78,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = isRegularUser ? otherCreators[index] : items[index];
                  if (item is CreatorModel) {
                    return HomeUserGridCard(creator: item);
                  }
                  if (item is UserProfileModel) {
                    return HomeUserGridCard(user: item);
                  }
                  return const SizedBox.shrink();
                },
                childCount: isRegularUser ? otherCreators.length : items.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatorTasksView extends ConsumerStatefulWidget {
  const _CreatorTasksView();

  @override
  ConsumerState<_CreatorTasksView> createState() => _CreatorTasksViewState();
}

class _CreatorTasksViewState extends ConsumerState<_CreatorTasksView> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final coins = authState.user?.coins ?? 0;
    final tasksAsync = ref.watch(creatorTasksProvider);
    final earningsAsync = ref.watch(creatorEarningsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(width: AppSpacing.md),
            _OnlinePill(),
            const Spacer(),
            _CoinsPill(coins: coins, isLoading: authState.isLoading),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        // Total Earnings Card
        earningsAsync.when(
          data: (earnings) => AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Earnings',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      earnings.totalEarnings.toStringAsFixed(0),
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'coins',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _EarningsStatItem(
                      label: 'Calls',
                      value: earnings.totalCalls.toString(),
                      icon: Icons.phone,
                    ),
                    const SizedBox(width: 24),
                    _EarningsStatItem(
                      label: 'Minutes',
                      value: earnings.totalMinutes.toStringAsFixed(1),
                      icon: Icons.timer,
                    ),
                  ],
                ),
              ],
            ),
          ),
          loading: () => AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: const SizedBox(
              height: 100,
              child: Center(child: LoadingIndicator()),
            ),
          ),
          error: (error, stack) => const SizedBox.shrink(), // Hide on error, don't block UI
        ),
        Text(
          'Tasks & Rewards',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: tasksAsync.when(
            data: (tasksResponse) => _TasksContent(
              tasksResponse: tasksResponse,
              onClaim: (taskKey) => _claimTask(taskKey),
            ),
            loading: () => const Center(child: LoadingIndicator()),
            error: (error, stack) => ErrorState(
              title: 'Failed to load tasks',
              message: error.toString(),
              actionLabel: 'Retry',
              onAction: () => ref.refresh(creatorTasksProvider),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _claimTask(String taskKey) async {
    try {
      await ref.read(creatorTaskServiceProvider).claimTaskReward(taskKey);
      
      // Optimistically update the provider
      ref.invalidate(creatorTasksProvider);
      
      if (mounted) {
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Reward claimed successfully!'),
            backgroundColor: scheme.primaryContainer,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to claim reward: ${e.toString()}'),
            backgroundColor: scheme.errorContainer,
          ),
        );
      }
    }
  }
}

// B) Next task preview - Pure UX sugar
class _NextTaskPreview extends StatelessWidget {
  final double totalMinutes;
  final List<CreatorTask> tasks;

  const _NextTaskPreview({
    required this.totalMinutes,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    // Find next uncompleted task
    try {
      final nextTask = tasks.firstWhere((task) => !task.isCompleted);
      final minutesNeeded = nextTask.thresholdMinutes - totalMinutes;
      
      if (minutesNeeded <= 0) {
        return const SizedBox.shrink();
      }

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: scheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.trending_up,
              size: 16,
              color: scheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Next reward in ${minutesNeeded.toStringAsFixed(0)} minutes (+${nextTask.rewardCoins} coins)',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      // All tasks completed
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.celebration,
              size: 16,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'All tasks completed! 🎉',
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}

class _TasksContent extends StatelessWidget {
  final CreatorTasksResponse tasksResponse;
  final Function(String) onClaim;

  const _TasksContent({
    required this.tasksResponse,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalMinutes = tasksResponse.totalMinutes;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Card: Total Minutes Completed
          AppCard(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Minutes Completed',
                  style: TextStyle(
                    color: scheme.onSurface.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppBrandGradients.walletCoinGold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${totalMinutes.toStringAsFixed(1)} mins',
                    style: const TextStyle(
                      color: AppBrandGradients.walletOnGold,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // B) Next task preview - "Next reward in X minutes"
                _NextTaskPreview(
                  totalMinutes: totalMinutes,
                  tasks: tasksResponse.tasks,
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete video calls to earn bonus coins!',
                  style: TextStyle(
                    color: scheme.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Progress Slider
          AppCard(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progress',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (totalMinutes / 600).clamp(0.0, 1.0),
                    minHeight: 12,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MilestoneMarker(
                      label: '1hr',
                      minutes: 60,
                      currentMinutes: totalMinutes,
                    ),
                    _MilestoneMarker(
                      label: '2hrs',
                      minutes: 120,
                      currentMinutes: totalMinutes,
                    ),
                    _MilestoneMarker(
                      label: '3hrs',
                      minutes: 180,
                      currentMinutes: totalMinutes,
                    ),
                    _MilestoneMarker(
                      label: '4hrs',
                      minutes: 240,
                      currentMinutes: totalMinutes,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Task List
          Text(
            'Tasks',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...tasksResponse.tasks.map((task) => _TaskCard(
                task: task,
                onClaim: () => onClaim(task.taskKey),
              )),
        ],
      ),
    );
  }
}

class _MilestoneMarker extends StatelessWidget {
  final String label;
  final int minutes;
  final double currentMinutes;

  const _MilestoneMarker({
    required this.label,
    required this.minutes,
    required this.currentMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isReached = currentMinutes >= minutes;

    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isReached ? scheme.primary : scheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isReached
                ? scheme.primary
                : scheme.onSurface.withOpacity(0.5),
            fontSize: 12,
            fontWeight: isReached ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final CreatorTask task;
  final VoidCallback onClaim;

  const _TaskCard({
    required this.task,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.isCompleted
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                ),
                child: task.isCompleted
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: scheme.onPrimary,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete ${task.thresholdMinutes} minutes',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${task.progressMinutes.toStringAsFixed(1)} / ${task.thresholdMinutes} minutes',
                      style: TextStyle(
                        color: scheme.onSurface.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: AppBrandGradients.walletCoinGold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${task.rewardCoins} coins',
                  style: const TextStyle(
                    color: AppBrandGradients.walletOnGold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: task.progressPercentage,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                task.isCompleted
                    ? scheme.primary
                    : scheme.primary.withOpacity(0.5),
              ),
            ),
          ),
          if (task.canClaim) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClaim,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Claim Reward'),
              ),
            ),
          ],
          if (task.isClaimed) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: scheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Reward claimed',
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OnlinePill extends ConsumerWidget {
  const _OnlinePill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final isCreator = authState.user?.role == 'creator' || authState.user?.role == 'admin';
    
    // Only show status for creators, for users just show a static "Online" indicator
    if (!isCreator) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.tertiary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Online',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      );
    }
    
    // For creators, show actual online/offline status
    final status = ref.watch(creatorStatusProvider);
    final isOnline = status == CreatorStatus.online;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _CoinsPill extends StatelessWidget {
  final int coins;
  final bool isLoading;

  const _CoinsPill({required this.coins, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monetization_on, size: 18, color: scheme.onSurface),
          const SizedBox(width: AppSpacing.xs),
          Text(
            isLoading ? '...' : coins.toString(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _EarningsStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _EarningsStatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: scheme.onSurfaceVariant, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
