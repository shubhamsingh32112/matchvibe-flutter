import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/widgets/app_nav_destinations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/vip_provider.dart';

final scheduledCallsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(vipApiServiceProvider).fetchScheduledCalls();
});

class ScheduledCallsScreen extends ConsumerWidget {
  const ScheduledCallsScreen({super.key});

  String _formatDateTime(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending_creator':
        return 'Awaiting creator';
      case 'confirmed':
        return 'Confirmed';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      case 'missed':
        return 'Missed';
      default:
        return status;
    }
  }

  Future<void> _cancelCall(
    BuildContext context,
    WidgetRef ref,
    String callId,
  ) async {
    try {
      await ref.read(vipApiServiceProvider).cancelScheduledCall(callId);
      ref.invalidate(scheduledCallsProvider);
      if (context.mounted) {
        AppToast.showSuccess(context, 'Scheduled call cancelled');
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.showError(context, 'Could not cancel call');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider.select((s) => s.user?.role));
    if (AppNavDestinations.isCreatorOrAdmin(role)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/recent');
      });
      return const SizedBox.shrink();
    }

    final callsAsync = ref.watch(scheduledCallsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Calls'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/vip'),
        ),
      ),
      body: callsAsync.when(
        loading: () => const Center(child: LoadingIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Could not load scheduled calls'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(scheduledCallsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (calls) {
          if (calls.isEmpty) {
            return const Center(
              child: Text('No scheduled calls yet'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(scheduledCallsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: calls.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final call = calls[index];
                final id = call['id']?.toString() ?? '';
                final status = call['status']?.toString() ?? '';
                final scheduledAt = call['scheduledAt']?.toString() ?? '';
                final duration =
                    (call['durationMinutes'] as num?)?.toInt() ?? 15;
                final canCancel =
                    status == 'pending_creator' || status == 'confirmed';

                return Card(
                  child: ListTile(
                    title: Text(_formatDateTime(scheduledAt)),
                    subtitle: Text(
                      '${_statusLabel(status)} · $duration min'
                      '${call['notes'] != null ? '\n${call['notes']}' : ''}',
                    ),
                    isThreeLine: call['notes'] != null,
                    trailing: canCancel
                        ? TextButton(
                            onPressed: id.isEmpty
                                ? null
                                : () => _cancelCall(context, ref, id),
                            child: const Text('Cancel'),
                          )
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
