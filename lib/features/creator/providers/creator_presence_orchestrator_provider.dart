import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../home/providers/availability_provider.dart' show socketServiceProvider;
import 'creator_status_provider.dart';

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
      if (socket.isConnected) {
        socket.emitCreatorOnline();
        socket.requestAvailability([uid]);
      }
      _ref.read(creatorStatusProvider.notifier).refreshOnResume();
      debugPrint('📡 [CREATOR PRESENCE] refresh complete (reason=$reason)');
    } catch (e) {
      debugPrint('⚠️ [CREATOR PRESENCE] refresh failed (reason=$reason): $e');
      _ref.read(creatorStatusProvider.notifier).refreshOnResume();
    } finally {
      _isRefreshing = false;
    }
  }
}

