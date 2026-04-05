import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../app/widgets/main_layout.dart';
import '../../../shared/widgets/skeleton_card.dart';
import '../../../shared/widgets/welcome_dialog.dart';
import '../../../shared/widgets/welcome_bonus_dialog.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../wallet/services/wallet_service.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/models/creator_model.dart';
import '../../../shared/models/profile_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/welcome_service.dart';
import '../../../core/services/permission_prompt_service.dart';
import '../providers/home_provider.dart';
import '../providers/availability_provider.dart';
import '../widgets/home_user_grid_card.dart';
import '../../creator/providers/creator_dashboard_provider.dart';
import '../../creator/providers/creator_task_provider.dart';
import '../../creator/models/creator_task_model.dart';
import '../../video/services/permission_service.dart';
import '../../admin/providers/admin_view_provider.dart';
import '../../support/services/support_service.dart';
import '../../video/providers/call_feedback_prompt_provider.dart';
import '../../video/providers/creator_busy_toast_provider.dart';
import '../../withdrawal/screens/withdrawal_screen.dart';
import '../../../shared/widgets/coin_purchase_popup.dart';
import '../../../shared/widgets/app_modal_bottom_sheet.dart';
import '../../../shared/providers/coin_purchase_popup_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _welcomeDialogShown = false;
  final SupportService _supportService = SupportService();
  String? _lastHandledFeedbackCallId;
  @override
  void initState() {
    super.initState();
    // Check and show welcome dialog if needed
    _checkAndShowWelcomeDialog();
    // Note: Video permissions are now requested after welcome bonus dialog
    // Connect Socket.IO and hydrate creator availability from Redis
    _initSocketAndHydrateAvailability();
    // Note: Coin purchase popup is now handled in AppLifecycleWrapper
    // to show once per app session, not every time user navigates to homepage
  }

  /// Connect to Socket.IO, then hydrate availability once creators are loaded.
  ///
  /// Sequence:
  ///   1. Get Firebase token
  ///   2. Connect socket (auth handshake)
  ///   3. Wait for creatorsProvider to resolve
  ///   4. Emit availability:get with all creator firebaseUids
  ///   5. Socket service auto-re-requests on reconnect
  Future<void> _initSocketAndHydrateAvailability() async {
    // Give the widget tree a moment to settle
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated || authState.firebaseUser == null) return;

    // Get a fresh Firebase ID token for the socket auth handshake
    final token = await authState.firebaseUser!.getIdToken();
    if (token == null || !mounted) return;

    // Connect socket (no-op if already connected)
    final socketService = ref.read(socketServiceProvider);
    socketService.connect(token);

    // Only request creator availability if the current user is a regular user
    // (or admin).  Creators don't need this — they see users, not creators.
    final user = authState.user;
    if (user?.role != 'creator') {
      try {
        final creators = await ref.read(creatorsProvider.future);
        if (!mounted) return;

        final creatorFirebaseUids = creators
            .where((c) => c.firebaseUid != null)
            .map((c) => c.firebaseUid!)
            .toList();

        if (creatorFirebaseUids.isNotEmpty) {
          socketService.requestAvailability(creatorFirebaseUids);
        }
      } catch (e) {
        debugPrint('❌ [HOME] Failed to hydrate availability: $e');
      }
    }
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
    
    // ✅ TASK 1: Wait for creators to load before showing welcome dialog
    // Only show welcome dialog when user can actually see creators on homepage
    final user = authState.user;
    if (user?.role == 'user' || (user?.role == 'admin' && ref.read(adminViewModeProvider) != AdminViewMode.creator)) {
      // For regular users (or admin viewing as user), wait for creators to load
      final creatorsLoaded = await _waitForCreatorsToLoad();
      if (!mounted) return;
      
      if (!creatorsLoaded) {
        debugPrint('⏭️  [HOME] Creators not loaded yet, skipping welcome dialog');
        // If creators don't load, still check for bonus (user might have seen welcome before)
        _checkAndShowBonusDialog();
        return;
      }
    }
    
    // Check if user has seen the welcome dialog
    final hasSeen = await WelcomeService.hasSeenWelcome();
    
    if (!mounted) return; // ✅ Guard: Check mounted after async operation
    
    if (!hasSeen && !_welcomeDialogShown) {
      _welcomeDialogShown = true;
      _showWelcomeDialog();
    } else {
      // Welcome dialog already seen — check for bonus
      _checkAndShowBonusDialog();
    }
  }

  /// ✅ TASK 2: Mark welcome as seen with retry mechanism for reliability
  /// Scalable: Uses efficient SharedPreferences (cached) with timeout
  Future<void> _markWelcomeAsSeenWithRetry({int maxRetries = 2}) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        await WelcomeService.markWelcomeAsSeen();
        // Verify it was saved
        final hasSeen = await WelcomeService.hasSeenWelcome();
        if (hasSeen) {
          debugPrint('✅ [HOME] Welcome dialog marked as seen (attempt ${attempt + 1})');
          return;
        }
      } catch (e) {
        debugPrint('⚠️  [HOME] Failed to mark welcome as seen (attempt ${attempt + 1}): $e');
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 200 * (attempt + 1)));
        }
      }
    }
    // If all retries failed, log but don't throw - dialog should still close
    debugPrint('⚠️  [HOME] Failed to mark welcome as seen after $maxRetries attempts');
  }

  /// Wait for creators to load and be visible on homepage
  /// Returns true when creators are loaded, false if timeout or error
  /// Scalable: Uses efficient provider watching with timeout
  Future<bool> _waitForCreatorsToLoad({int maxAttempts = 10}) async {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (!mounted) return false;
      
      // Check if creators are loaded via homeFeedProvider
      final homeFeedItems = ref.read(homeFeedProvider);
      
      // If we have items (creators), they're loaded
      if (homeFeedItems.isNotEmpty) {
        debugPrint('✅ [HOME] Creators loaded: ${homeFeedItems.length} items');
        return true;
      }
      
      // Also check creatorsProvider directly for more accurate state
      final creatorsAsync = ref.read(creatorsProvider);
      if (creatorsAsync.hasValue) {
        final creators = creatorsAsync.value ?? [];
        if (creators.isNotEmpty) {
          debugPrint('✅ [HOME] Creators loaded via provider: ${creators.length} creators');
          return true;
        }
      }
      
      // Wait before next attempt (exponential backoff for scalability)
      await Future.delayed(Duration(milliseconds: 200 * (attempt + 1)));
    }
    
    debugPrint('⏭️  [HOME] Creators not loaded after ${maxAttempts} attempts');
    return false;
  }

  void _showWelcomeDialog() {
    if (!mounted) return; // ✅ Guard: Never show bottom sheet if widget is disposed
    
    showAppModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => WelcomeBottomSheet(
        onAgree: () async {
          // ✅ TASK 2: Improved error handling with retry mechanism
          try {
            // Mark as seen with retry logic
            await _markWelcomeAsSeenWithRetry();
            
            if (mounted && context.mounted) { // ✅ Guard: Check both mounted and context.mounted
              Navigator.of(context).pop();
            }
            
            // ✅ TASK 3: After welcome bottom sheet dismissed, wait 2 seconds then check for bonus
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                _checkAndShowBonusDialog();
              }
            });
          } catch (e) {
            debugPrint('❌ [HOME] Error in welcome dialog onAgree: $e');
            // Even on error, try to close dialog to prevent stuck state
            if (mounted && context.mounted) {
              Navigator.of(context).pop();
            }
            // Still schedule bonus dialog - user should see it even if save failed
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                _checkAndShowBonusDialog();
              }
            });
          }
        },
      ),
    );
  }

  /// Show the 30-coin welcome bonus dialog if:
  ///   1. User is a regular user (not creator/admin)
  ///   2. User hasn't already claimed the bonus (backend flag)
  ///   3. The dialog hasn't already been shown on this device (local flag)
  Future<void> _checkAndShowBonusDialog() async {
    if (!mounted) return;
    final authState = ref.read(authProvider);
    final user = authState.user;

    // Only for regular users who haven't claimed
    if (user == null || user.role != 'user' || user.welcomeBonusClaimed) {
      return;
    }

    // Check local persistent flag — once shown, never show again
    final firebaseUid = authState.firebaseUser?.uid;
    if (firebaseUid == null) return;

    final alreadyShown = await WelcomeService.hasBonusDialogBeenShown(firebaseUid);
    if (alreadyShown) return;

    // Mark as shown BEFORE displaying (prevents race conditions on fast rebuilds)
    await WelcomeService.markBonusDialogShown(firebaseUid);

    // Show bonus dialog (delay already handled in welcome dialog callback)
    if (mounted) {
      _showBonusDialog();
    }
  }

  bool _isBonusClaiming = false;

  void _showBonusDialog() {
    showAppModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBottomSheetState) => WelcomeBonusBottomSheet(
          isLoading: _isBonusClaiming,
          onAccept: () async {
            setBottomSheetState(() => _isBonusClaiming = true);
            try {
              final walletService = WalletService();
              final newCoins = await walletService.claimWelcomeBonus();
              // Update auth state with new coins + claimed flag
              if (mounted) {
                ref.read(authProvider.notifier).refreshUser();
              }
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                AppToast.showSuccess(
                  context,
                  '🎉 You received 30 coins! Balance: $newCoins',
                );
              }
            } catch (e) {
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                AppToast.showError(
                  context,
                  UserMessageMapper.userMessageFor(
                    e,
                    fallback: 'Couldn\'t claim bonus. Please try again.',
                  ),
                );
              }
            } finally {
              _isBonusClaiming = false;
            }
            // Schedule video permissions request after bonus bottom sheet is handled
            _scheduleVideoPermissionRequest();
          },
          onDecline: () {
            Navigator.of(ctx).pop();
            // Schedule video permissions request after bonus bottom sheet is handled
            _scheduleVideoPermissionRequest();
          },
        ),
      ),
    );
  }

  /// Schedule video permissions request with a delay after welcome bonus dialog
  /// ✅ TASK 4: Changed to 2 seconds as per requirements
  void _scheduleVideoPermissionRequest() {
    // Wait 2 seconds after bonus dialog is dismissed before requesting permissions
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _checkAndRequestVideoPermissions();
      }
    });
  }

  /// Check and request video permissions for users
  Future<void> _checkAndRequestVideoPermissions() async {
    // Wait for auth state to be available
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    final authState = ref.read(authProvider);
    final user = authState.user;
    
    // Only request permissions for regular users (they can make video calls)
    if (user == null || user.role != 'user') {
      return;
    }
    
    // Check if permissions are already granted
    final hasPermissions = await PermissionService.hasCameraAndMicrophonePermissions();
    
    if (!mounted) return;
    
    if (hasPermissions) {
      debugPrint('✅ [HOME] Camera and microphone permissions already granted');
      return;
    }
    
    // 🔥 CRITICAL: Check persistent flag (not session flag)
    final hasShownPrompt = await PermissionPromptService.hasShownPermissionPrompt();
    
    if (!mounted) return;
    
    if (hasShownPrompt) {
      debugPrint('⏭️  [HOME] Permission prompt already shown (persisted)');
      return;
    }
    
    // Wait a bit more for UI to stabilize
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (!mounted) return;
    
    // Mark as shown BEFORE showing dialog (prevents race conditions)
    await PermissionPromptService.markPermissionPromptAsShown();
    
    if (!mounted) return;
    _showVideoPermissionDialog();
  }

  /// Show dialog requesting video permissions
  void _showVideoPermissionDialog() {
    if (!mounted) return;
    
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
              if (mounted && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (mounted && context.mounted) {
                Navigator.of(context).pop();
              }
              
              try {
                final granted = await PermissionService.ensureCameraAndMicrophonePermissions();
                
                if (!mounted) return;
                
                if (granted) {
                  if (mounted && context.mounted) {
                    AppToast.showSuccess(
                      context,
                      'Permissions granted! You can now make video calls.',
                      duration: const Duration(seconds: 2),
                    );
                  }
                } else {
                  if (mounted && context.mounted) {
                    AppToast.showErrorWithAction(
                      context,
                      'Permissions are required for video calls. Enable them in Settings.',
                      actionLabel: 'Settings',
                      onAction: () {
                        unawaited(PermissionService.openAppSettings());
                      },
                      duration: const Duration(seconds: 4),
                    );
                  }
                }
              } catch (e) {
                if (!mounted) return;
                
                if (mounted && context.mounted) {
                  AppToast.showError(
                    context,
                    UserMessageMapper.userMessageFor(
                      e,
                      fallback: 'Couldn\'t update permissions. Please try again.',
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
    // Show toast when creator didn't pick up (navigated from call screen)
    final creatorBusyToast = ref.watch(creatorBusyToastProvider);
    if (creatorBusyToast != null && creatorBusyToast.isNotEmpty) {
      final message = creatorBusyToast;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final current = ref.read(creatorBusyToastProvider);
        if (current == null) return;
        ref.read(creatorBusyToastProvider.notifier).state = null;
        AppToast.showInfo(context, message);
      });
    }

    final pendingFeedbackPrompt = ref.watch(callFeedbackPromptProvider);
    if (pendingFeedbackPrompt != null &&
        _lastHandledFeedbackCallId != pendingFeedbackPrompt.callId) {
      _lastHandledFeedbackCallId = pendingFeedbackPrompt.callId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showPostCallFeedbackDialog(pendingFeedbackPrompt);
      });
    }

    final homeFeedItems = ref.watch(homeFeedProvider); // Now a Provider, not FutureProvider
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isCreator = user?.role == 'creator' || user?.role == 'admin';
    final scheme = Theme.of(context).colorScheme;

    // Listen for coin purchase pop-up trigger
    final showCoinPopup = ref.watch(coinPurchasePopupProvider);
    if (showCoinPopup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          hideCoinPurchasePopup(ref);
          showAppModalBottomSheet(
            context: context,
            builder: (context) => const CoinPurchaseBottomSheet(),
          );
        }
      });
    }

    return MainLayout(
        selectedIndex: 0,
        child: AppScaffold(
          padded: true,
          child: isCreator
            ? _CreatorTasksView()
            : _buildHomeFeedContent(homeFeedItems, scheme, isCreator),
      ),
    );
  }

  void _showPostCallFeedbackDialog(CallFeedbackPrompt prompt) {
    ref.read(callFeedbackPromptProvider.notifier).clear();
    int selectedStars = 0;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            prompt.creatorName?.trim().isNotEmpty == true
                ? 'Rate ${prompt.creatorName}'
                : 'Rate Creator',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('How was your video call experience?'),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return IconButton(
                    onPressed: isSubmitting
                        ? null
                        : () => setDialogState(() => selectedStars = starIndex),
                    icon: Icon(
                      starIndex <= selectedStars ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          Navigator.of(ctx).pop();
                          _showCreatorReportDialog(
                            creatorLookupId: prompt.creatorLookupId,
                            creatorFirebaseUid: prompt.creatorFirebaseUid,
                            creatorName: prompt.creatorName,
                            relatedCallId: prompt.callId,
                            source: 'post_call',
                          );
                        },
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Report creator'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: (isSubmitting || selectedStars < 1)
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      try {
                        await _supportService.submitCallFeedback(
                          callId: prompt.callId,
                          rating: selectedStars,
                        );
                        if (!mounted || !ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        AppToast.showSuccess(
                          context,
                          'Thanks! Your rating was submitted.',
                        );
                      } catch (e) {
                        if (!mounted) return;
                        AppToast.showError(
                          context,
                          UserMessageMapper.userMessageFor(
                            e,
                            fallback: 'Couldn\'t submit rating. Please try again.',
                          ),
                        );
                        setDialogState(() => isSubmitting = false);
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatorReportDialog({
    String? creatorLookupId,
    String? creatorFirebaseUid,
    String? creatorName,
    String? relatedCallId,
    required String source,
  }) {
    final controller = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Report Creator'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  creatorName?.trim().isNotEmpty == true
                      ? 'Tell us what happened with ${creatorName!.trim()}.'
                      : 'Tell us what happened.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Write your complaint',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final message = controller.text.trim();
                      if (message.length < 10) {
                        AppToast.showInfo(
                          context,
                          'Please write at least 10 characters.',
                        );
                        return;
                      }

                      if (!ctx.mounted) return;
                      setDialogState(() => isSubmitting = true);
                      try {
                        await _supportService.reportCreator(
                          reasonMessage: message,
                          source: source,
                          creatorLookupId: creatorLookupId,
                          creatorFirebaseUid: creatorFirebaseUid,
                          creatorName: creatorName,
                          relatedCallId: relatedCallId,
                        );
                        if (!mounted || !ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        AppToast.showSuccess(
                          context,
                          'Report submitted to admin team.',
                        );
                      } catch (e) {
                        if (!mounted || !ctx.mounted) return;
                        AppToast.showError(
                          context,
                          UserMessageMapper.userMessageFor(
                            e,
                            fallback: 'Couldn\'t send report. Please try again.',
                          ),
                        );
                        setDialogState(() => isSubmitting = false);
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send Report'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      // Delay disposal to avoid transient "used after disposed" during route
      // transition / IME teardown on some Android builds.
      Future<void>.delayed(const Duration(milliseconds: 250), controller.dispose);
    });
  }

  Widget _buildHomeFeedContent(List<dynamic> items, ColorScheme scheme, bool isCreator) {
    // Show loading state while creators are being fetched
    final creatorsAsync = ref.watch(creatorsProvider);
    final isLoading = creatorsAsync.isLoading;
    
    if (isLoading) {
      return GridView.builder(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.xs,
          mainAxisSpacing: AppSpacing.xs,
          childAspectRatio: 0.70,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => const SkeletonCard(),
      );
    }
    
    // Show empty state if no items
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          final beforeRole = ref.read(authProvider).user?.role;
          await ref.read(authProvider.notifier).refreshUser();
          final afterRole = ref.read(authProvider).user?.role;
          if (mounted &&
              beforeRole != 'creator' &&
              afterRole == 'creator') {
            AppToast.showSuccess(
              context,
              'You are now a creator. Home has been updated.',
            );
          }
          ref.invalidate(creatorsProvider);
          ref.invalidate(usersProvider);
          ref.invalidate(homeFeedProvider);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: EmptyState(
              icon: isCreator ? Icons.people_outline : Icons.person_outline,
              title: isCreator ? 'No users available' : 'No creators available',
              message: isCreator ? 'Users will appear here when they join' : 'Creators will appear here when they join',
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Manual refresh - invalidate providers to force refetch
        debugPrint('🔄 [HOME] Manual refresh triggered');
        final beforeRole = ref.read(authProvider).user?.role;
        await ref.read(authProvider.notifier).refreshUser();
        final afterRole = ref.read(authProvider).user?.role;
        if (mounted &&
            beforeRole != 'creator' &&
            afterRole == 'creator') {
          AppToast.showSuccess(
            context,
            'You are now a creator. Home has been updated.',
          );
        }
        ref.invalidate(creatorsProvider);
        ref.invalidate(usersProvider);
        ref.invalidate(homeFeedProvider);
        // Wait a bit for the refresh to complete
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.xs,
                mainAxisSpacing: AppSpacing.xs,
                childAspectRatio: 0.70,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = items[index];
                  if (item is CreatorModel) {
                    return HomeUserGridCard(creator: item);
                  }
                  if (item is UserProfileModel) {
                    return HomeUserGridCard(user: item);
                  }
                  return const SizedBox.shrink();
                },
                childCount: items.length,
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
  void initState() {
    super.initState();
    // 🔥 FIX: Removed automatic dashboard invalidation on init
    // Dashboard updates automatically via socket events (creator:data_updated)
    // This prevents constant reloads when navigating to homepage
    // Manual refresh button is available if needed
  }

  @override
  Widget build(BuildContext context) {
    // Use dashboard-derived providers (auto-synced via creator:data_updated socket event)
    final tasksAsync = ref.watch(dashboardTasksProvider);
    final earningsAsync = ref.watch(dashboardEarningsProvider);
    // 🔥 FIX: dashboardCoinsProvider is now a Provider (not FutureProvider) for instant updates
    final balance = ref.watch(dashboardCoinsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        // Balance Card (shows current balance, not total earned)
        // Note: We use earningsAsync for stats (calls, minutes) but balance from auth state for instant updates
        earningsAsync.when(
            data: (earnings) => AppCard(
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Balance label and Manual Refresh button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Balance',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // Manual refresh button for creators
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Refresh balance',
                        onPressed: () async {
                          debugPrint('🔄 [CREATOR HOME] Manual refresh triggered');
                          // Refresh both dashboard and auth user
                          ref.invalidate(creatorDashboardProvider);
                          await ref.read(authProvider.notifier).refreshUser();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        iconSize: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        balance.toString(),
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
            error: (error, stack) => AppCard(
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: const SizedBox(
                height: 100,
                child: Center(child: LoadingIndicator()),
              ),
            ),
        ),
        // Withdrawal Button
        AppCard(
          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const WithdrawalScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Request Withdrawal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        // Task Progress Button - Opens bottom sheet on click
        tasksAsync.when(
          data: (tasksResponse) => _TaskProgressButton(
            tasksResponse: tasksResponse,
            onTap: () => _showTaskProgressBottomSheet(context, tasksResponse),
          ),
          loading: () => AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: const SizedBox(
              height: 80,
              child: Center(child: LoadingIndicator()),
            ),
          ),
          error: (error, stack) => AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Failed to load tasks',
                    style: TextStyle(color: scheme.error),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(creatorDashboardProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _claimTask(String taskKey) async {
    try {
      await ref.read(creatorTaskServiceProvider).claimTaskReward(taskKey);
      
      // Invalidate dashboard to refresh all creator data (earnings + tasks + coins)
      ref.invalidate(creatorDashboardProvider);
      
      if (mounted) {
        AppToast.showSuccess(context, 'Reward claimed successfully!');
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          UserMessageMapper.userMessageFor(
            e,
            fallback: 'Couldn\'t claim reward. Please try again.',
          ),
        );
      }
    }
  }

  void _showTaskProgressBottomSheet(
    BuildContext context,
    CreatorTasksResponse tasksResponse,
  ) {
    showAppModalBottomSheet(
      context: context,
      builder: (context) => TaskProgressBottomSheet(
        tasksResponse: tasksResponse,
        onClaim: (taskKey) => _claimTask(taskKey),
      ),
    );
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
                  "Today's Minutes",
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
                  'Tasks reset daily at 11:59 PM. Complete calls to earn bonus coins!',
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

          // Daily Reset Countdown
          if (tasksResponse.resetsAt != null)
            _DailyResetBanner(resetsAt: tasksResponse.resetsAt!),

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

/// Compact daily reset countdown for the home screen.
class _DailyResetBanner extends StatefulWidget {
  final DateTime resetsAt;

  const _DailyResetBanner({required this.resetsAt});

  @override
  State<_DailyResetBanner> createState() => _DailyResetBannerState();
}

class _DailyResetBannerState extends State<_DailyResetBanner> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    final now = DateTime.now();
    final diff = widget.resetsAt.toLocal().difference(now);
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
  }

  @override
  void didUpdateWidget(_DailyResetBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetsAt != widget.resetsAt) {
      _updateRemaining();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes.remainder(60);
    final seconds = _remaining.inSeconds.remainder(60);

    final timeText = hours > 0
        ? '${hours}h ${minutes}m ${seconds}s'
        : minutes > 0
            ? '${minutes}m ${seconds}s'
            : '${seconds}s';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 16, color: scheme.tertiary),
          const SizedBox(width: 8),
          Text(
            'Resets in ',
            style: TextStyle(
              color: scheme.onTertiaryContainer.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
          Text(
            timeText,
            style: TextStyle(
              color: scheme.tertiary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
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

/// Bottom sheet wrapper for task progress screen
class TaskProgressBottomSheet extends StatelessWidget {
  final CreatorTasksResponse tasksResponse;
  final Function(String) onClaim;

  const TaskProgressBottomSheet({
    super.key,
    required this.tasksResponse,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Tasks & Rewards',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: _TasksContent(
                  tasksResponse: tasksResponse,
                  onClaim: onClaim,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact button widget that shows task progress summary
class _TaskProgressButton extends StatelessWidget {
  final CreatorTasksResponse tasksResponse;
  final VoidCallback onTap;

  const _TaskProgressButton({
    required this.tasksResponse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalMinutes = tasksResponse.totalMinutes;
    final completedTasks = tasksResponse.tasks.where((t) => t.isCompleted).length;
    final totalTasks = tasksResponse.tasks.length;
    final progressPercentage = (totalMinutes / 600).clamp(0.0, 1.0);

    // Find next uncompleted task
    String? nextTaskText;
    try {
      final nextTask = tasksResponse.tasks.firstWhere((task) => !task.isCompleted);
      final minutesNeeded = nextTask.thresholdMinutes - totalMinutes;
      if (minutesNeeded > 0) {
        nextTaskText = '${minutesNeeded.toStringAsFixed(0)} min to next reward';
      }
    } catch (e) {
      // All tasks completed
      nextTaskText = 'All tasks completed! 🎉';
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.task_alt,
                      color: scheme.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tasks & Rewards',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${totalMinutes.toStringAsFixed(1)} minutes completed',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressPercentage,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$completedTasks / $totalTasks tasks completed',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  if (nextTaskText != null)
                    Text(
                      nextTaskText,
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
