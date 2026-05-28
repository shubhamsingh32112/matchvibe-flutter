import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/socket_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/availability_provider.dart';

enum CreatorStatus {
  online,
  offline,
}

/// Creator self online/offline status for the app bar.
///
/// Uses [SocketService] (not legacy AvailabilitySocketService). Optimistic
/// online while the production socket is connected; backend [creator:status]
/// and the availability map confirm or override (e.g. on-call → busy).
final creatorStatusProvider =
    StateNotifierProvider<CreatorStatusNotifier, CreatorStatus>((ref) {
  return CreatorStatusNotifier(ref);
});

class CreatorStatusNotifier extends StateNotifier<CreatorStatus> {
  final Ref _ref;
  ProviderSubscription<String?>? _ownUidSub;

  CreatorStatusNotifier(this._ref) : super(CreatorStatus.offline) {
    _initializeStatus();
    _watchOwnAvailability();
  }

  @override
  void dispose() {
    _ownUidSub?.close();
    super.dispose();
  }

  bool get _isCreatorRole {
    final user = _ref.read(authProvider).user;
    return user != null && (user.role == 'creator' || user.role == 'admin');
  }

  SocketService get _socket => _ref.read(socketServiceProvider);

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
  }

  void _applyStatusFromSources({CreatorAvailability? ownAvailability}) {
    if (!_isCreatorRole) {
      state = CreatorStatus.offline;
      return;
    }

    final socketConnected = _socket.isConnected;
    if (!socketConnected) {
      state = CreatorStatus.offline;
      return;
    }

    final uid = _ref.read(authProvider).firebaseUser?.uid;
    ownAvailability ??=
        uid != null ? _ref.read(creatorAvailabilityProvider)[uid] : null;

    if (ownAvailability == CreatorAvailability.busy) {
      state = CreatorStatus.offline;
      return;
    }

    // Connected and not explicitly busy → show online immediately.
    state = CreatorStatus.online;
  }

  /// Called when [SocketService] connects or disconnects (from [socketServiceProvider]).
  void updateFromSocketConnection(bool isConnected) {
    if (!_isCreatorRole) return;

    if (!isConnected) {
      state = CreatorStatus.offline;
      debugPrint('📡 [CREATOR STATUS] Socket disconnected → offline');
      return;
    }

    _applyStatusFromSources();
    debugPrint('📡 [CREATOR STATUS] Socket connected → online (optimistic)');

    // Hydrate own UID so on-call busy updates reach the app bar via the map.
    final uid = _ref.read(authProvider).firebaseUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      _socket.requestAvailability([uid]);
    }
  }

  bool get isOnline => state == CreatorStatus.online;
}
