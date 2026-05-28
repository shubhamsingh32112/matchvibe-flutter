import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../shared/widgets/app_toast.dart';
import '../providers/support_provider.dart';

/// Dedupe rapid duplicate socket events for the same ticket update.
final _recentSupportUpdatesMs = <String, int>{};
const _dedupeWindowMs = 10000;

void handleSupportTicketSocketUpdate(Ref ref, Map<String, dynamic> data) {
  final ticketId = data['ticketId']?.toString();
  if (ticketId == null || ticketId.isEmpty) return;

  final updatedAt = data['updatedAt']?.toString() ?? '';
  final dedupeKey = '$ticketId|$updatedAt';
  final now = DateTime.now().millisecondsSinceEpoch;
  final last = _recentSupportUpdatesMs[dedupeKey];
  if (last != null && (now - last) < _dedupeWindowMs) return;
  _recentSupportUpdatesMs[dedupeKey] = now;
  if (_recentSupportUpdatesMs.length > 50) {
    _recentSupportUpdatesMs.removeWhere((_, ts) => (now - ts) > _dedupeWindowMs);
  }

  final notifier = ref.read(supportProvider.notifier);
  final hadTicket = ref.read(supportProvider).tickets.any((t) => t.id == ticketId);
  notifier.applyTicketUpdate(data);
  if (!hadTicket) {
    notifier.loadTickets();
  }

  // Trust server flag only — adminNotes in payload is cumulative, not "new this event".
  if (data['hasNewReply'] != true) return;

  final subject = data['subject']?.toString().trim();
  final ctx = appRouter.routerDelegate.navigatorKey.currentContext;
  if (ctx == null || !ctx.mounted) return;

  final location =
      GoRouter.of(ctx).routeInformationProvider.value.uri.path;
  if (location.startsWith('/support')) return;

  final label = subject != null && subject.isNotEmpty ? subject : 'your ticket';
  AppToast.showInfo(ctx, 'Support replied to: $label');
  debugPrint('🎫 [SUPPORT] In-app notification for ticket $ticketId');
}
