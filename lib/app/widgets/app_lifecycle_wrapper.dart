import 'package:flutter/material.dart';
import 'dart:async' show StreamSubscription, unawaited;
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../router/app_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/home/providers/availability_provider.dart';
import '../../features/creator/providers/creator_dashboard_provider.dart';
import '../../features/video/controllers/call_connection_controller.dart';
import '../../features/home/providers/home_provider.dart';
import '../../shared/widgets/coin_purchase_popup.dart';
import '../../shared/widgets/app_modal_bottom_sheet.dart';
import '../../shared/widgets/app_update_popup.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/models/app_update_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/modal_coordinator_service.dart';
import '../../features/onboarding/services/onboarding_runner_lock_service.dart';
import '../../features/onboarding/services/onboarding_popup_state_service.dart';
import '../../shared/services/app_update_service.dart';
import '../../shared/providers/coin_purchase_popup_provider.dart';
import '../../shared/providers/app_update_popup_provider.dart';
import '../../core/services/permission_reconciliation_service.dart';

/// Widget that wraps the app and handles lifecycle events.
///
/// - Shows popup for creators when app opens.
/// - Sets creator offline when app goes to background.
///
/// 🔥 CRITICAL: All active-call checks now use [CallConnectionController]
/// (the single source of truth), NOT `streamVideo.state.activeCall`.
class AppLifecycleWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const AppLifecycleWrapper({super.key, required this.child});

  @override
  ConsumerState<AppLifecycleWrapper> createState() =>
      _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends ConsumerState<AppLifecycleWrapper>
    with WidgetsBindingObserver {
  static const String _lastHandledPaymentDeepLinkKey =
      'last_handled_payment_deep_link';
  static const String _deferredUpdateAcksKey = 'deferred_update_acks_v1';
  static const String _seenAppUpdatesKey = 'seen_app_updates_v1';
  static const String _deferredAppUpdateKey = 'deferred_app_update_v1';
  static const int _seenAppUpdatesTtlMs = 48 * 60 * 60 * 1000; // 48h
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _deepLinkSub;
  bool _coinPopupShownThisSession = false;
  final AppUpdateService _appUpdateService = AppUpdateService();
  String? _lastDeferredAppUpdateId;
  bool _isAppUpdatePopupPresenting = false;
  AppUpdateModel? _deferredAppUpdate;
  bool _isCheckingPendingAppUpdate = false;
  bool _isDrainingModalQueue = false;
  ProviderSubscription<ModalCoordinatorState>? _modalQueueSub;
  ProviderSubscription<CoinPopupIntent?>? _coinPopupSub;
  ProviderSubscription<AppUpdatePopupState>? _appUpdatePopupSub;
  ProviderSubscription<AuthState>? _authSub;
  ProviderSubscription<CallConnectionState>? _callStateSub;
  bool _isForcingOverlayDismiss = false;

  bool _isInActiveCallPhase() {
    final phase = ref.read(callConnectionControllerProvider).phase;
    return phase == CallConnectionPhase.preparing ||
        phase == CallConnectionPhase.joining ||
        phase == CallConnectionPhase.connected;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
    _setupProviderListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(socketServiceProvider);
      _ensureCreatorOnline();
      _maybeShowCoinPopupForCurrentState();
      unawaited(_retryDeferredUpdateAcks());
      unawaited(_refreshPendingAppUpdate());
    });
  }

  @override
  void dispose() {
    _modalQueueSub?.close();
    _coinPopupSub?.close();
    _appUpdatePopupSub?.close();
    _authSub?.close();
    _callStateSub?.close();
    _deepLinkSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupProviderListeners() {
    _modalQueueSub = ref.listenManual<ModalCoordinatorState>(
      modalCoordinatorProvider,
      (prev, next) {
        if (next.queue.isNotEmpty && !next.isPresenting) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _drainModalQueue();
          });
        }
      },
    );

    _coinPopupSub = ref.listenManual<CoinPopupIntent?>(
      coinPurchasePopupProvider,
      (prev, next) {
        if (next == null) return;
        if (_isInActiveCallPhase()) {
          debugPrint(
            '🛑 [CALL_OVERLAY] modal_blocked_during_call type=coin_popup phase=${ref.read(callConnectionControllerProvider).phase}',
          );
          return;
        }
        final shouldSuppress = ref
            .read(modalCoordinatorProvider)
            .onboardingInProgress;
        if (shouldSuppress) return;
        final id = ref
            .read(modalCoordinatorProvider.notifier)
            .nextRequestId('coin');
        ref
            .read(modalCoordinatorProvider.notifier)
            .enqueue<void>(
              AppModalRequest<void>(
                id: id,
                priority: AppModalPriority.normal,
                dedupeKey: next.dedupeKey,
                present: (ctx, _) => showAppModalBottomSheet<void>(
                  context: ctx,
                  builder: (_) => const CoinPurchaseBottomSheet(),
                ),
                onCompleted: (_) {
                  ref.read(coinPurchasePopupProvider.notifier).state = null;
                },
              ),
            );
      },
    );

    _appUpdatePopupSub = ref.listenManual<AppUpdatePopupState>(
      appUpdatePopupProvider,
      (prev, next) {
        final pending = next.pendingUpdate;
        if (pending == null) return;
        final source = next.source ?? 'unknown';
        unawaited(_handleIncomingAppUpdate(pending, source: source));
      },
    );

    _authSub = ref.listenManual<AuthState>(authProvider, (prev, next) {
      final prevUid = prev?.firebaseUser?.uid;
      final nextUid = next.firebaseUser?.uid;
      if (prevUid != nextUid) {
        // Best-effort: dismiss any active modal bottom sheet before clearing queue
        // to avoid leaving an overlay alive with inconsistent dedupe/flags.
        final modalState = ref.read(modalCoordinatorProvider);
        if (!_isForcingOverlayDismiss &&
            modalState.isPresenting &&
            modalState.onboardingInProgress) {
          _isForcingOverlayDismiss = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              if (!mounted) return;
              await Navigator.of(context, rootNavigator: true).maybePop();
            } finally {
              _isForcingOverlayDismiss = false;
            }
          });
        }
        // Shared-device safety: clear any leftover modal state and onboarding locks.
        ref.read(modalCoordinatorProvider.notifier).clearQueue();
        if (prevUid != null) {
          unawaited(OnboardingRunnerLockService.clear(prevUid));
          unawaited(OnboardingPopupStateService.clearAllForUser(prevUid));
        }
        if (nextUid != null) {
          unawaited(OnboardingRunnerLockService.clear(nextUid));
        }
      }
      final user = next.user;
      final isCreator =
          user != null && (user.role == 'creator' || user.role == 'admin');
      if (next.isAuthenticated && isCreator) {
        _ensureCreatorOnline();
      }

      if (prev != null &&
          next.isAuthenticated &&
          !_coinPopupShownThisSession &&
          user != null &&
          user.role == 'user') {
        _showCoinPurchasePopupOnAppOpen();
      }
      if (next.isAuthenticated && user != null) {
        unawaited(_retryDeferredUpdateAcks());
        unawaited(_refreshPendingAppUpdate());
      }
    });

    _callStateSub = ref.listenManual<CallConnectionState>(
      callConnectionControllerProvider,
      (prev, next) {
        final wasInCall = prev != null &&
            (prev.phase == CallConnectionPhase.preparing ||
                prev.phase == CallConnectionPhase.joining ||
                prev.phase == CallConnectionPhase.connected);
        final isInCall = next.phase == CallConnectionPhase.preparing ||
            next.phase == CallConnectionPhase.joining ||
            next.phase == CallConnectionPhase.connected;
        if (wasInCall && !isInCall) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _drainModalQueue();
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_flushDeferredAppUpdateIfAny());
          });
        }
      },
    );
  }

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  int? _updateVersionMs(AppUpdateModel update) {
    final raw = update.version.trim();
    return int.tryParse(raw);
  }

  String? _currentFirebaseUid() {
    return ref.read(authProvider).firebaseUser?.uid;
  }

  Future<Set<String>> _loadSeenUpdateIds() async {
    final prefs = await _prefs();
    final raw = prefs.getStringList(_seenAppUpdatesKey) ?? <String>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    final kept = <String>[];
    final seen = <String>{};
    for (final row in raw) {
      final parts = row.split('|');
      if (parts.length != 2) continue;
      final id = parts[0].trim();
      final ts = int.tryParse(parts[1].trim());
      if (id.isEmpty || ts == null) continue;
      if (now - ts > _seenAppUpdatesTtlMs) continue;
      if (seen.add(id)) {
        kept.add('$id|$ts');
      }
    }
    if (kept.length != raw.length) {
      await prefs.setStringList(_seenAppUpdatesKey, kept);
    }
    return seen;
  }

  Future<void> _markUpdateSeen(String updateId) async {
    final id = updateId.trim();
    if (id.isEmpty) return;
    final prefs = await _prefs();
    final now = DateTime.now().millisecondsSinceEpoch;
    final raw = prefs.getStringList(_seenAppUpdatesKey) ?? <String>[];
    await prefs.setStringList(_seenAppUpdatesKey, [...raw, '$id|$now']);
  }

  Future<bool> _shouldShowAndMarkSeen(AppUpdateModel update) async {
    final seen = await _loadSeenUpdateIds();
    if (seen.contains(update.id)) return false;
    await _markUpdateSeen(update.id);
    return true;
  }

  Future<void> _persistDeferredAppUpdate(AppUpdateModel update) async {
    final prefs = await _prefs();
    final safeTitle = update.title.replaceAll('|', ' ');
    final safeUrl = update.updateUrl.replaceAll('|', '%7C');
    await prefs.setString(
      _deferredAppUpdateKey,
      '${update.id}|${update.version}|$safeTitle|$safeUrl',
    );
  }

  Future<void> _clearDeferredAppUpdatePersisted() async {
    final prefs = await _prefs();
    await prefs.remove(_deferredAppUpdateKey);
  }

  Future<void> _flushDeferredAppUpdateIfAny() async {
    if (_deferredAppUpdate == null) return;
    if (_isInActiveCallPhase()) return;
    if (_isAppUpdatePopupPresenting) return;
    final pending = _deferredAppUpdate!;
    _deferredAppUpdate = null;
    await _clearDeferredAppUpdatePersisted();
    _enqueueAppUpdatePopup(pending, source: 'deferred');
  }

  Future<void> _handleIncomingAppUpdate(
    AppUpdateModel pending, {
    required String source,
  }) async {
    // Prefer newest only (when comparable).
    final incomingVersion = _updateVersionMs(pending);
    final deferredVersion =
        _deferredAppUpdate == null ? null : _updateVersionMs(_deferredAppUpdate!);
    if (incomingVersion != null && deferredVersion != null) {
      if (incomingVersion < deferredVersion) {
        debugPrint(
          '[AppUpdate] received_ignored source=$source updateId=${pending.id} reason=older_than_deferred',
        );
        return;
      }
    }

    final shouldShow = await _shouldShowAndMarkSeen(pending);
    debugPrint(
      '[AppUpdate] received source=$source updateId=${pending.id} deduped=${!shouldShow}',
    );
    if (!shouldShow) return;

    if (_isInActiveCallPhase()) {
      _deferredAppUpdate = pending;
      await _persistDeferredAppUpdate(pending);
      debugPrint(
        '[AppUpdate] deferred_during_call source=$source updateId=${pending.id} phase=${ref.read(callConnectionControllerProvider).phase}',
      );
      return;
    }

    if (_isAppUpdatePopupPresenting) {
      debugPrint(
        '[AppUpdate] dropped_already_presenting source=$source updateId=${pending.id}',
      );
      return;
    }

    ref.read(appUpdatePopupProvider.notifier).clearPendingUpdate();
    _enqueueAppUpdatePopup(pending, source: source);
  }

  void _maybeShowCoinPopupForCurrentState() {
    final authState = ref.read(authProvider);
    if (authState.isAuthenticated &&
        !_coinPopupShownThisSession &&
        authState.user != null &&
        authState.user!.role == 'user') {
      _showCoinPurchasePopupOnAppOpen();
    }
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

    // Referral: app://signup?ref=CODE or zztherapy://signup?ref=CODE
    if ((uri.scheme == 'app' || uri.scheme == 'zztherapy') &&
        uri.host == 'signup') {
      final raw = uri.queryParameters['ref'];
      if (raw == null || raw.trim().isEmpty) {
        debugPrint('🔗 [APP LINKS] signup deep link without ref → /login');
        appRouter.go('/login');
        return;
      }
      final trimmed = raw.trim();
      debugPrint('🔗 [APP LINKS] signup deep link ref=$trimmed');
      appRouter.go(
        Uri(path: '/login', queryParameters: {'ref': trimmed}).toString(),
      );
      return;
    }

    if (uri.scheme != 'zztherapy') return;
    if (uri.host != 'wallet') return;

    final paymentStatus =
        uri.queryParameters['status'] ?? uri.queryParameters['payment'];
    if (paymentStatus == null || paymentStatus.isEmpty) return;

    if (!await _shouldHandlePaymentDeepLink(uri, paymentStatus)) {
      debugPrint('⏭️  [APP LINKS] Ignoring duplicate payment deep link: $uri');
      return;
    }

    final coinsAdded =
        int.tryParse(
          uri.queryParameters['walletDelta'] ??
              uri.queryParameters['coinsAdded'] ??
              '0',
        ) ??
        0;
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
      appRouter.go(
        Uri(path: '/wallet/payment-status', queryParameters: params).toString(),
      );
      return;
    }

    if (paymentStatus == 'failed') {
      final params = <String, String>{'payment': 'failed'};
      if (deepLinkMessage != null && deepLinkMessage.isNotEmpty) {
        params['message'] = deepLinkMessage;
      } else {
        params['message'] = 'Payment failed or cancelled. Please try again.';
      }
      appRouter.go(
        Uri(path: '/wallet/payment-status', queryParameters: params).toString(),
      );
    }
  }

  Future<void> _onCreatorOrAdminResumed() async {
    await ref.read(authProvider.notifier).refreshUser();
    await _refreshPendingAppUpdate();
    await _maybeToastProfileUpdatedByAdmin();
    ref.invalidate(creatorDashboardProvider);
  }

  Future<void> _refreshPendingAppUpdate() async {
    if (_isCheckingPendingAppUpdate) return;
    final auth = ref.read(authProvider);
    final user = auth.user;
    if (!auth.isAuthenticated || user == null) return;
    if (user.role != 'user' && user.role != 'creator' && user.role != 'admin') {
      return;
    }
    _isCheckingPendingAppUpdate = true;
    try {
      final pending = await _appUpdateService.getPendingUpdate();
      if (pending != null && pending.id != _lastDeferredAppUpdateId) {
        ref.read(appUpdatePopupProvider.notifier).setPendingUpdate(
              pending,
              source: 'rest',
            );
      }
    } catch (e) {
      int? status;
      dynamic body;
      if (e is DioException) {
        status = e.response?.statusCode;
        body = e.response?.data;
      }
      final uid = _currentFirebaseUid();
      final bodyStr = body == null ? null : body.toString();
      final truncated = bodyStr == null
          ? null
          : (bodyStr.length > 800 ? bodyStr.substring(0, 800) : bodyStr);
      debugPrint(
        '[AppUpdate] pending_failed status=$status uid=$uid body=$truncated error=$e',
      );
    } finally {
      _isCheckingPendingAppUpdate = false;
    }
  }

  Future<List<Map<String, String>>> _loadDeferredUpdateAcks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_deferredUpdateAcksKey) ?? <String>[];
    final items = <Map<String, String>>[];
    for (final row in raw) {
      final parts = row.split('|');
      if (parts.length != 2) continue;
      final updateId = parts[0].trim();
      final updateUrl = parts[1].trim();
      if (updateId.isEmpty || updateUrl.isEmpty) continue;
      items.add({'id': updateId, 'url': updateUrl});
    }
    return items;
  }

  Future<void> _saveDeferredUpdateAcks(List<Map<String, String>> items) async {
    final prefs = await SharedPreferences.getInstance();
    final rows = items
        .map((e) => '${e['id'] ?? ''}|${e['url'] ?? ''}')
        .where((e) => e != '|')
        .toList();
    await prefs.setStringList(_deferredUpdateAcksKey, rows);
  }

  Future<void> _addDeferredUpdateAck(String updateId, String updateUrl) async {
    final items = await _loadDeferredUpdateAcks();
    final exists = items.any((i) => i['id'] == updateId);
    if (!exists) {
      items.add({'id': updateId, 'url': updateUrl});
      await _saveDeferredUpdateAcks(items);
    }
  }

  Future<void> _removeDeferredUpdateAck(String updateId) async {
    final items = await _loadDeferredUpdateAcks();
    items.removeWhere((i) => i['id'] == updateId);
    await _saveDeferredUpdateAcks(items);
  }

  Future<void> _retryDeferredUpdateAcks() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.user == null) return;
    final items = await _loadDeferredUpdateAcks();
    if (items.isEmpty) return;
    final remaining = <Map<String, String>>[];
    for (final item in items) {
      final id = item['id'];
      if (id == null || id.isEmpty) continue;
      try {
        await _appUpdateService.ackUpdateNow(id);
      } catch (_) {
        remaining.add(item);
      }
    }
    await _saveDeferredUpdateAcks(remaining);
  }

  void _enqueueAppUpdatePopup(AppUpdateModel pending, {required String source}) {
    final requestId = ref
        .read(modalCoordinatorProvider.notifier)
        .nextRequestId('app-update');
    ref.read(modalCoordinatorProvider.notifier).enqueue<AppUpdatePopupAction>(
          AppModalRequest<AppUpdatePopupAction>(
            id: requestId,
            priority: AppModalPriority.high,
            dedupeKey: 'app-update-${pending.id}',
            present: (ctx, _) async {
              _isAppUpdatePopupPresenting = true;
              var submitting = false;
              return showAppModalBottomSheet<AppUpdatePopupAction>(
                context: ctx,
                isDismissible: false,
                enableDrag: false,
                builder: (sheetContext) {
                  return StatefulBuilder(
                    builder: (context, setState) {
                      return AppUpdatePopup(
                        title: pending.title,
                        points: pending.points,
                        isSubmitting: submitting,
                        onLater: () {
                          Navigator.of(context).pop(AppUpdatePopupAction.later);
                        },
                        onUpdateNow: () async {
                          if (submitting) return;
                          setState(() => submitting = true);
                          try {
                            final uri = Uri.tryParse(pending.updateUrl);
                            if (uri == null) {
                              throw Exception('Invalid update URL');
                            }
                            final launched = await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                            if (!launched) {
                              throw Exception('Could not launch update URL');
                            }
                            try {
                              await _appUpdateService.ackUpdateNow(pending.id);
                            } catch (_) {
                              // Launch succeeded but ack failed (likely network). Retry later.
                              await _addDeferredUpdateAck(
                                pending.id,
                                pending.updateUrl,
                              );
                            }
                            if (context.mounted) {
                              Navigator.of(context).pop(AppUpdatePopupAction.updateNow);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              AppToast.showError(
                                context,
                                'Unable to open update right now. Please try again.',
                              );
                            }
                            setState(() => submitting = false);
                          }
                        },
                      );
                    },
                  );
                },
              );
            },
            onCompleted: (result) {
              _isAppUpdatePopupPresenting = false;
              if (result == AppUpdatePopupAction.updateNow) {
                unawaited(_removeDeferredUpdateAck(pending.id));
                ref.read(appUpdatePopupProvider.notifier).clearPendingUpdate();
                _lastDeferredAppUpdateId = null;
              } else {
                _lastDeferredAppUpdateId = pending.id;
              }
              debugPrint(
                '[AppUpdate] completed source=$source updateId=${pending.id} action=$result',
              );
            },
          ),
        );
  }

  /// When [UserModel.profileRevision] increases (admin edited profile), show a one-time toast.
  Future<void> _maybeToastProfileUpdatedByAdmin() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    if (user.role != 'creator' && user.role != 'admin') return;

    final prefs = await SharedPreferences.getInstance();
    final key = '${AppConstants.keyAckProfileRevisionPrefix}${user.id}';
    final ack = prefs.getInt(key) ?? 0;
    final current = user.profileRevision;
    if (current <= ack) return;

    await prefs.setInt(key, current);
    ref.invalidate(homeFeedProvider);
    ref.invalidate(creatorsProvider);

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppToast.showInfo(
        context,
        'Your profile was updated by our team. Check your profile if anything looks off.',
      );
    });
  }

  Future<bool> _shouldHandlePaymentDeepLink(
    Uri uri,
    String paymentStatus,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = uri.queryParameters['sessionId'];
      final dedupeId = (sessionId != null && sessionId.isNotEmpty)
          ? '$paymentStatus:$sessionId'
          : uri.toString();

      final lastHandled = prefs.getString(_lastHandledPaymentDeepLinkKey);
      if (lastHandled == dedupeId) {
        return false;
      }

      await prefs.setString(_lastHandledPaymentDeepLinkKey, dedupeId);
      return true;
    } catch (e) {
      debugPrint(
        '⚠️  [APP LINKS] Failed to persist deep link dedupe state: $e',
      );
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
    final controllerPhase = ref.read(callConnectionControllerProvider).phase;
    final hasActiveCall =
        controllerPhase != CallConnectionPhase.idle &&
        controllerPhase != CallConnectionPhase.failed;

    if (state == AppLifecycleState.resumed) {
      // 🔥 Firebase ID token expires ~1hr: refresh proactively on app resume
      if (user != null) {
        ref.read(authProvider.notifier).refreshAuthToken();
      }

      // 🔥 CRITICAL: DO NOT navigate from lifecycle — causes race conditions.
      // Only log / refresh data.  Navigation is owned by CallConnectionController.
      if (hasActiveCall) {
        debugPrint(
          '📱 [APP LIFECYCLE] App resumed with active call (phase: $controllerPhase)',
        );
        debugPrint('   Call screen should already be visible — not navigating');
      }

      // Refresh home feed + profile when app resumes (promotion to creator syncs role)
      if (user != null && user.role == 'user') {
        debugPrint(
          '📱 [APP LIFECYCLE] App resumed — refreshing home feed + user for user',
        );
        ref.invalidate(homeFeedProvider);
        unawaited(ref.read(authProvider.notifier).refreshUser());
        unawaited(_refreshPendingAppUpdate());
        // Permissions reconciliation: if permissions changed post-onboarding, report once.
        if (user.onboardingStage == 'completed') {
          unawaited(() async {
            final uid = ref.read(authProvider).firebaseUser?.uid;
            if (uid == null) return;
            final ok = await PermissionReconciliationService.shouldAttemptNow(uid);
            if (!ok) return;
            final changed =
                await PermissionReconciliationService.hasMeaningfulChange(uid);
            if (!changed) return;
            final requestId =
                'perm_reconcile_${DateTime.now().microsecondsSinceEpoch}';
            await PermissionReconciliationService.sendReconcile(
              uid: uid,
              requestId: requestId,
            );
            debugPrint(
              '[ONBOARDING_PERMISSION_RECONCILE] sent uid=$uid requestId=$requestId',
            );
          }());
        }
      }

      // Creators / admins: refresh profile (profileRevision toast) + dashboard
      if (user != null && (user.role == 'creator' || user.role == 'admin')) {
        debugPrint(
          '📱 [APP LIFECYCLE] App resumed — refreshing user + creator dashboard',
        );
        unawaited(_onCreatorOrAdminResumed());
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Keep creators online while app is alive, including background.
      // Socket connection remains active, so creator stays online
      if (user != null && (user.role == 'creator' || user.role == 'admin')) {
        debugPrint(
          '📱 [APP LIFECYCLE] App backgrounded — socket keeps creator online',
        );
      }
    } else if (state == AppLifecycleState.detached) {
      // App closed — socket disconnect will automatically mark creator offline
      // Backend socket handler handles this automatically
      if (user != null && (user.role == 'creator' || user.role == 'admin')) {
        debugPrint(
          '📱 [APP LIFECYCLE] App closed — socket disconnect will auto-set creator offline',
        );
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
    if (user == null || (user.role != 'creator' && user.role != 'admin')) {
      return;
    }

    // 🔥 AUTOMATIC: Socket connection automatically handles online/offline
    // When socket connects, backend sets creator online automatically
    // When socket disconnects, backend sets creator offline automatically
    // No manual status setting needed
    debugPrint(
      '✅ [APP LIFECYCLE] Socket connection handles creator status automatically',
    );
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

    ref.read(coinPurchasePopupProvider.notifier).state = const CoinPopupIntent(
      reason: 'session_start',
      dedupeKey: 'coin-session-start',
    );
  }

  Future<void> _drainModalQueue() async {
    if (_isDrainingModalQueue || !mounted) return;
    if (_isInActiveCallPhase()) {
      debugPrint(
        '🛑 [CALL_OVERLAY] modal_queue_deferred_while_in_call phase=${ref.read(callConnectionControllerProvider).phase}',
      );
      return;
    }
    _isDrainingModalQueue = true;
    try {
      while (mounted) {
        final state = ref.read(modalCoordinatorProvider);
        if (state.isPresenting || state.queue.isEmpty) break;
        final request = ref.read(modalCoordinatorProvider.notifier).takeNext();
        if (request == null) break;
        final result = await request.present(context, ref);
        if (!mounted) break;
        ref
            .read(modalCoordinatorProvider.notifier)
            .complete(request.id, result, dedupeKey: request.dedupeKey);
        request.onCompleted?.call(result);
      }
    } finally {
      _isDrainingModalQueue = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authProvider);
    return widget.child;
  }
}
