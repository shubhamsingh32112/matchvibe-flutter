import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../video/controllers/call_connection_controller.dart';
import '../providers/vip_call_queue_provider.dart';
import '../providers/vip_provider.dart';

/// Global overlay for VIP call queue status and ready-to-ring confirmation.
class VipCallQueueOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const VipCallQueueOverlay({super.key, required this.child});

  @override
  ConsumerState<VipCallQueueOverlay> createState() =>
      _VipCallQueueOverlayState();
}

class _VipCallQueueOverlayState extends ConsumerState<VipCallQueueOverlay> {
  VipReadyToRingRequest? _shownReadyToRing;

  @override
  Widget build(BuildContext context) {
    ref.listen<VipCallQueueState>(vipCallQueueProvider, (prev, next) {
      final pending = next.pendingReadyToRing;
      if (pending == null || identical(pending, _shownReadyToRing)) return;
      _shownReadyToRing = pending;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_showReadyToRingDialog(pending));
      });
    });

    final queueState = ref.watch(vipCallQueueProvider);
    final topEntry = queueState.entries.isNotEmpty
        ? queueState.entries.first
        : null;

    return Stack(
      children: [
        widget.child,
        if (topEntry != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 88,
            child: _VipQueueBanner(
              entry: topEntry,
              onLeaveQueue: () => _leaveQueue(topEntry.creatorFirebaseUid),
            ),
          ),
      ],
    );
  }

  Future<void> _leaveQueue(String creatorFirebaseUid) async {
    try {
      await ref.read(vipApiServiceProvider).leaveCallQueue(creatorFirebaseUid);
      ref
          .read(vipCallQueueProvider.notifier)
          .removeEntry(creatorFirebaseUid);
      if (mounted) {
        AppToast.showInfo(context, 'Left the call queue');
      }
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, 'Could not leave queue. Please try again.');
      }
    }
  }

  Future<void> _showReadyToRingDialog(VipReadyToRingRequest request) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.workspace_premium, color: Color(0xFFFF8F00)),
        title: const Text('Your turn!'),
        content: const Text(
          'A creator is now available. Start your VIP priority call?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Call now'),
          ),
        ],
      ),
    );

    ref.read(vipCallQueueProvider.notifier).clearReadyToRing();
    _shownReadyToRing = null;

    if (confirmed == true && mounted) {
      await ref.read(callConnectionControllerProvider.notifier).startUserCall(
            creatorFirebaseUid: request.creatorFirebaseUid,
            creatorMongoId: request.creatorId,
          );
    }
  }
}

class _VipQueueBanner extends StatelessWidget {
  final VipQueueEntry entry;
  final VoidCallback onLeaveQueue;

  const _VipQueueBanner({
    required this.entry,
    required this.onLeaveQueue,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xFFFFF3E0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top, color: Color(0xFFE65100), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.position <= 1
                    ? "You're next in line — we'll connect you when they're free."
                    : "You're #${entry.position} in line — we'll connect you when they're free.",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE65100),
                ),
              ),
            ),
            TextButton(
              onPressed: onLeaveQueue,
              child: const Text('Leave'),
            ),
          ],
        ),
      ),
    );
  }
}
