import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/availability_provider.dart';
import '../providers/creator_status_provider.dart' as creator_self_status;
import '../services/creator_availability_service.dart';
import 'creator_presence_orchestrator_provider.dart';

class CreatorAvailabilityToggleState {
  const CreatorAvailabilityToggleState({
    this.toggleOn = false,
    this.isSyncing = false,
    this.hasLoadedPersisted = false,
    this.error,
  });

  final bool toggleOn;
  final bool isSyncing;
  final bool hasLoadedPersisted;
  final String? error;

  CreatorAvailabilityToggleState copyWith({
    bool? toggleOn,
    bool? isSyncing,
    bool? hasLoadedPersisted,
    String? error,
    bool clearError = false,
  }) {
    return CreatorAvailabilityToggleState(
      toggleOn: toggleOn ?? this.toggleOn,
      isSyncing: isSyncing ?? this.isSyncing,
      hasLoadedPersisted: hasLoadedPersisted ?? this.hasLoadedPersisted,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final creatorAvailabilityToggleProvider =
    StateNotifierProvider<CreatorAvailabilityToggleNotifier,
        CreatorAvailabilityToggleState>((ref) {
  return CreatorAvailabilityToggleNotifier(ref);
});

class CreatorAvailabilityToggleNotifier
    extends StateNotifier<CreatorAvailabilityToggleState> {
  CreatorAvailabilityToggleNotifier(this._ref)
      : super(const CreatorAvailabilityToggleState()) {
    _init();
  }

  final Ref _ref;
  final CreatorAvailabilityService _service = CreatorAvailabilityService();
  bool _localMutationInFlight = false;
  ProviderSubscription<CreatorAvailability?>? _ownAvailabilitySub;

  bool get _isCreatorRole {
    final user = _ref.read(authProvider).user;
    return user != null && (user.role == 'creator' || user.role == 'admin');
  }

  Future<void> _init() async {
    if (!_isCreatorRole) return;
    await _loadPersistedToggle();
    _watchOwnAvailabilityForRemoteSync();
  }

  Future<void> _loadPersistedToggle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(AppConstants.keyCreatorAvailabilityToggle)) {
        state = state.copyWith(hasLoadedPersisted: true);
        return;
      }
      final stored = prefs.getBool(AppConstants.keyCreatorAvailabilityToggle) ?? false;
      state = state.copyWith(toggleOn: stored, hasLoadedPersisted: true, clearError: true);
      debugPrint('📡 [CREATOR TOGGLE] Loaded persisted toggle=$stored');
    } catch (e) {
      debugPrint('⚠️ [CREATOR TOGGLE] Failed to load persisted toggle: $e');
      state = state.copyWith(hasLoadedPersisted: true);
    }
  }

  /// Seed from Mongo profile when no local pref exists (first launch after migration).
  Future<void> seedFromProfileIfNeeded(bool profileIsOnline) async {
    if (!_isCreatorRole) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(AppConstants.keyCreatorAvailabilityToggle)) {
      return;
    }
    await _persistToggle(profileIsOnline);
    state = state.copyWith(toggleOn: profileIsOnline, clearError: true);
    debugPrint(
      '📡 [CREATOR TOGGLE] Seeded from profile isOnline=$profileIsOnline',
    );
    if (profileIsOnline) {
      unawaited(
        _ref
            .read(creatorPresenceOrchestratorProvider)
            .refreshPresence(reason: 'toggle_seed_profile_online'),
      );
    }
  }

  /// Reconcile device cache with Mongo after dashboard fetch (multi-device).
  Future<void> reconcileFromProfile(bool profileIsOnline) async {
    if (!_isCreatorRole || _localMutationInFlight) return;
    if (profileIsOnline == state.toggleOn) return;
    await _persistToggle(profileIsOnline);
    if (mounted) {
      state = state.copyWith(toggleOn: profileIsOnline, clearError: true);
    }
    debugPrint(
      '📡 [CREATOR TOGGLE] Reconciled pref with Mongo isOnline=$profileIsOnline',
    );
  }

  void _watchOwnAvailabilityForRemoteSync() {
    _ownAvailabilitySub?.close();
    if (!_isCreatorRole) return;

    _ownAvailabilitySub = _ref.listen<CreatorAvailability?>(
      creatorAvailabilityProvider.select((m) {
        final uid = _ref.read(authProvider).firebaseUser?.uid;
        if (uid == null || uid.isEmpty) return null;
        return m[uid];
      }),
      (previous, next) {
        if (_localMutationInFlight || next == null) return;
        if (next == CreatorAvailability.onCall) return;
        final shouldBeOn = next == CreatorAvailability.online;
        if (shouldBeOn != state.toggleOn) {
          unawaited(_applyRemoteToggle(shouldBeOn));
        }
      },
    );
  }

  Future<void> _applyRemoteToggle(bool isOn) async {
    debugPrint('📡 [CREATOR TOGGLE] Remote sync → $isOn');
    await _persistToggle(isOn);
    if (mounted) {
      state = state.copyWith(toggleOn: isOn, clearError: true);
    }
  }

  Future<void> _persistToggle(bool isOn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyCreatorAvailabilityToggle, isOn);
  }

  void _applyOptimisticOwnAvailability(bool wantOn) {
    final uid = _ref.read(authProvider).firebaseUser?.uid;
    if (uid == null || uid.isEmpty) return;
    if (wantOn) {
      _ref
          .read(creatorAvailabilityProvider.notifier)
          .applyCallLifecycleHint(uid, CreatorAvailability.online);
    } else {
      _ref
          .read(creatorAvailabilityProvider.notifier)
          .applyCallLifecycleHint(uid, CreatorAvailability.offline);
    }
  }

  /// User flipped the app-bar switch.
  Future<void> setToggle(bool wantOn) async {
    if (!_isCreatorRole || state.isSyncing) return;

    final status = _ref.read(creator_self_status.creatorStatusProvider);
    if (!wantOn && status == creator_self_status.CreatorStatus.onCall) {
      state = state.copyWith(
        error: 'Finish or leave the call before going offline',
      );
      return;
    }

    final wasOnCall = status == creator_self_status.CreatorStatus.onCall;
    final previous = state.toggleOn;
    _localMutationInFlight = true;
    state = state.copyWith(toggleOn: wantOn, isSyncing: true, clearError: true);
    _applyOptimisticOwnAvailability(wantOn);

    var emitSucceeded = false;
    final socket = _ref.read(socketServiceProvider);

    try {
      final auth = _ref.read(authProvider);
      final fbUser = auth.firebaseUser;
      if (fbUser == null) {
        throw Exception('Not signed in');
      }

      final token = await fbUser.getIdToken();
      if (token != null && token.isNotEmpty) {
        await socket.ensureConnected(token);
      }

      if (socket.isConnected) {
        if (wantOn) {
          socket.emitCreatorOnline(clearStuckCall: wasOnCall);
        } else {
          socket.emitCreatorOffline();
        }
        emitSucceeded = true;
      }

      final confirmedOnline = await _service.setOnlineStatus(wantOn);

      await _persistToggle(confirmedOnline);
      state = state.copyWith(
        toggleOn: confirmedOnline,
        isSyncing: false,
        clearError: true,
      );

      if (confirmedOnline) {
        final uid = fbUser.uid;
        if (uid.isNotEmpty) {
          socket.requestAvailability([uid]);
        }
      }
      debugPrint('✅ [CREATOR TOGGLE] Set availability isOnline=$confirmedOnline');
    } catch (e) {
      debugPrint('❌ [CREATOR TOGGLE] Failed: $e');
      if (emitSucceeded && socket.isConnected) {
        debugPrint(
          '⚠️ [CREATOR TOGGLE] presence.toggle_patch_after_emit_failed — rolling back socket',
        );
        if (wantOn) {
          socket.emitCreatorOffline();
        } else {
          socket.emitCreatorOnline();
        }
      }
      _applyOptimisticOwnAvailability(previous);
      state = state.copyWith(
        toggleOn: previous,
        isSyncing: false,
        error: e.toString(),
      );
    } finally {
      _localMutationInFlight = false;
    }
  }

  /// Best-effort Mongo intent off before socket disconnect (logout).
  Future<void> setIntentOfflineForLogout() async {
    try {
      await _service.setOnlineStatus(false);
    } catch (e) {
      debugPrint('⚠️ [CREATOR TOGGLE] Logout PATCH isOnline=false failed: $e');
    }
    await clearOnLogout();
  }

  /// Logout — local cache off (Mongo via setIntentOfflineForLogout).
  Future<void> clearOnLogout() async {
    await _persistToggle(false);
    if (mounted) {
      state = const CreatorAvailabilityToggleState(
        toggleOn: false,
        hasLoadedPersisted: true,
      );
    }
  }

  @override
  void dispose() {
    _ownAvailabilitySub?.close();
    super.dispose();
  }
}
