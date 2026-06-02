import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../home/providers/availability_provider.dart' show socketServiceProvider;
import 'creator_availability_toggle_provider.dart';
import 'creator_status_provider.dart' as creator_self_status;

final creatorPresenceOrchestratorProvider = Provider<CreatorPresenceOrchestrator>(
  (ref) => CreatorPresenceOrchestrator(ref),
);

class CreatorPresenceOrchestrator {
  CreatorPresenceOrchestrator(this._ref);

  final Ref _ref;
  bool _isRefreshing = false;

  Future<void> refreshPresence({String reason = 'unknown'}) async {
    if (_isRefreshing) return;
    final auth = _ref.read(authProvider);
    final user = auth.user;
    final firebaseUser = auth.firebaseUser;
    final isCreator = user != null && (user.role == 'creator' || user.role == 'admin');
    final uid = firebaseUser?.uid;
    if (!isCreator || uid == null || uid.isEmpty) return;
    final fbUser = firebaseUser;
    if (fbUser == null) return;

    _isRefreshing = true;
    try {
      final socket = _ref.read(socketServiceProvider);
      final token = await fbUser.getIdToken();
      if (token != null && token.isNotEmpty) {
        await socket.ensureConnected(token);
      }
      final toggleOn = _ref.read(creatorAvailabilityToggleProvider).toggleOn;
      if (socket.isConnected) {
        if (toggleOn) {
          final status = _ref.read(creator_self_status.creatorStatusProvider);
          socket.emitCreatorOnline(
            clearStuckCall: status == creator_self_status.CreatorStatus.onCall,
          );
        }
        socket.requestAvailability([uid]);
      }
      _ref.read(creator_self_status.creatorStatusProvider.notifier).refreshOnResume();
      debugPrint('📡 [CREATOR PRESENCE] refresh complete (reason=$reason)');
    } catch (e) {
      debugPrint('⚠️ [CREATOR PRESENCE] refresh failed (reason=$reason): $e');
      _ref.read(creator_self_status.creatorStatusProvider.notifier).refreshOnResume();
    } finally {
      _isRefreshing = false;
    }
  }
}

