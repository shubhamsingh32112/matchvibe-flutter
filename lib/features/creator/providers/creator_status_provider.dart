import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/socket_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/availability_provider.dart';
import 'creator_availability_toggle_provider.dart';
import 'creator_presence_orchestrator_provider.dart';

enum CreatorStatus {
  syncing,
  online,
  onCall,
  offline,
}

/// Creator self online/offline/on_call status for the app bar.
///
/// Uses [SocketService] (not legacy AvailabilitySocketService). Optimistic
/// online while the production socket is connected; backend [creator:status]
/// and the availability map confirm or override (e.g. on-call → onCall).
final creatorStatusProvider =
    StateNotifierProvider<CreatorStatusNotifier, CreatorStatus>((ref) {
  return CreatorStatusNotifier(ref);
});

class CreatorStatusNotifier extends StateNotifier<CreatorStatus> {
  CreatorStatusNotifier(this._ref) : super(CreatorStatus.offline) {
    _initializeStatus();
    _watchOwnAvailability();
  }

  static const Duration _disconnectGrace = Duration(seconds: 3);

  final Ref _ref;
  ProviderSubscription<String?>? _ownUidSub;
  Timer? _disconnectGraceTimer;
  bool _desyncRetryScheduled = false;

  bool get _toggleOn => _ref.read(creatorAvailabilityToggleProvider).toggleOn;

  @override
  void dispose() {
    _disconnectGraceTimer?.cancel();
    _ownUidSub?.close();
    super.dispose();
  }

  bool get _isCreatorRole {
    final user = _ref.read(authProvider).user;
    return user != null && (user.role == 'creator' || user.role == 'admin');
  }

  SocketService get _socket => _ref.read(socketServiceProvider);

  bool get _hasAuthoritativeSelfAvailability {
    final uid = _ref.read(authProvider).firebaseUser?.uid;
    if (uid == null || uid.isEmpty) return false;
    return _ref.read(creatorAvailabilityProvider).containsKey(uid);
  }

  void _initializeStatus() {
    if (!_isCreatorRole) {
      state = CreatorStatus.offline;
      return;
    }
    _applyStatusFromSources();
  }

  /// Re-subscribe when [firebaseUser] arrives after app start (common on cold launch).
  void _watchOwnAvailability() {
    _ownUidSub?.close();
    if (!_isCreatorRole) return;

    _ownUidSub = _ref.listen<String?>(
      authProvider.select((s) => s.firebaseUser?.uid),
      (previous, next) {
        if (!_isCreatorRole || next == null || next.isEmpty) return;
        _applyStatusFromSources(
          ownAvailability: _ref.read(creatorAvailabilityProvider)[next],
        );
      },
      fireImmediately: true,
    );

    _ref.listen<CreatorAvailability?>(
      creatorAvailabilityProvider.select((m) {
        final uid = _ref.read(authProvider).firebaseUser?.uid;
        if (uid == null || uid.isEmpty) return null;
        return m[uid];
      }),
      (previous, next) {
        if (!_isCreatorRole) return;
        _applyStatusFromSources(ownAvailability: next);
      },
    );

    _ref.listen<bool>(
      creatorAvailabilityToggleProvider.select((s) => s.toggleOn),
      (previous, next) {
        if (!_isCreatorRole) return;
        _applyStatusFromSources();
      },
    );
  }

  void _applyStatusFromSources({CreatorAvailability? ownAvailability}) {
    if (!_isCreatorRole) {
      state = CreatorStatus.offline;
      return;
    }

    final socketConnected = _socket.isConnected;
    if (!socketConnected) {
      if (_toggleOn) {
        state = CreatorStatus.syncing;
        _scheduleDesyncRecovery('socket_disconnected_toggle_on');
      } else {
        state = CreatorStatus.offline;
      }
      return;
    }

    final uid = _ref.read(authProvider).firebaseUser?.uid;
    ownAvailability ??=
        uid != null ? _ref.read(creatorAvailabilityProvider)[uid] : null;

    if (ownAvailability == CreatorAvailability.onCall) {
      state = CreatorStatus.onCall;
      return;
    }

    if (ownAvailability == CreatorAvailability.offline) {
      if (_toggleOn) {
        state = CreatorStatus.syncing;
        _scheduleDesyncRecovery('runtime_offline_toggle_on');
      } else {
        state = CreatorStatus.offline;
      }
      return;
    }

    if (ownAvailability == CreatorAvailability.online) {
      state = CreatorStatus.online;
      return;
    }

    // Socket is up but we don't yet have an authoritative self record.
    if (_toggleOn) {
      _scheduleDesyncRecovery('awaiting_self_presence');
    }
    state = CreatorStatus.syncing;
  }

  void _scheduleDesyncRecovery(String reason) {
    if (_desyncRetryScheduled || !_toggleOn) return;
    _desyncRetryScheduled = true;
    unawaited(() async {
      try {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!_toggleOn) return;
        await _ref
            .read(creatorPresenceOrchestratorProvider)
            .refreshPresence(reason: 'status_desync_$reason');
      } finally {
        _desyncRetryScheduled = false;
      }
    }());
  }

  /// Refresh own presence after app/tab resume (creator home).
  void refreshOnResume() {
    if (!_isCreatorRole) return;
    _disconnectGraceTimer?.cancel();
    _applyStatusFromSources();
  }

  /// Called when [SocketService] connects or disconnects (from [socketServiceProvider]).
  void updateFromSocketConnection(bool isConnected) {
    if (!_isCreatorRole) return;

    if (!isConnected) {
      _disconnectGraceTimer?.cancel();
      _disconnectGraceTimer = Timer(_disconnectGrace, () {
        if (!_socket.isConnected) {
          if (_toggleOn) {
            state = CreatorStatus.syncing;
            _scheduleDesyncRecovery('socket_grace_elapsed_toggle_on');
          } else {
            state = CreatorStatus.offline;
          }
          debugPrint(
            '📡 [CREATOR STATUS] Socket disconnected past grace → ${_toggleOn ? "syncing (toggle on)" : "offline"}',
          );
        }
      });
      return;
    }

    _disconnectGraceTimer?.cancel();
    _applyStatusFromSources();
    if (!_hasAuthoritativeSelfAvailability) {
      state = CreatorStatus.syncing;
    }
    debugPrint('📡 [CREATOR STATUS] Socket connected → awaiting authoritative self presence');

    final uid = _ref.read(authProvider).firebaseUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      _socket.requestAvailability([uid]);
    }
  }

  bool get isOnline => state == CreatorStatus.online;
  bool get isOnCall => state == CreatorStatus.onCall;
}
