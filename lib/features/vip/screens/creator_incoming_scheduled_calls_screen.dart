import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/vip_provider.dart';

final incomingScheduledCallsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(vipApiServiceProvider).fetchIncomingScheduledCalls();
});

class CreatorIncomingScheduledCallsScreen extends ConsumerWidget {
  const CreatorIncomingScheduledCallsScreen({super.key});

  String _formatDateTime(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmCall(
    BuildContext context,
    WidgetRef ref,
    String callId,
  ) async {
    try {
      await ref.read(vipApiServiceProvider).confirmScheduledCall(callId);
      ref.invalidate(incomingScheduledCallsProvider);
      if (context.mounted) {
        AppToast.showSuccess(context, 'Call confirmed');
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.showError(context, 'Could not confirm call');
      }
    }
  }

  Future<void> _declineCall(
    BuildContext context,
    WidgetRef ref,
    String callId,
  ) async {
    try {
      await ref.read(vipApiServiceProvider).cancelScheduledCall(callId);
      ref.invalidate(incomingScheduledCallsProvider);
      if (context.mounted) {
        AppToast.showInfo(context, 'Call declined');
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.showError(context, 'Could not decline call');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider.select((s) => s.user?.role));
    final isCreator = role == 'creator' || role == 'admin';
    if (!isCreator) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/home');
      });
      return const SizedBox.shrink();
    }

    final callsAsync = ref.watch(incomingScheduledCallsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('VIP Scheduled Calls'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
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
                onPressed: () => ref.invalidate(incomingScheduledCallsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (calls) {
          if (calls.isEmpty) {
            return const Center(
              child: Text('No incoming VIP schedule requests'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(incomingScheduledCallsProvider),
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
                final isPending = status == 'pending_creator';

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.workspace_premium,
                              color: Color(0xFFFF8F00),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'VIP request',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            Text(status.replaceAll('_', ' ')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_formatDateTime(scheduledAt)),
                        Text('$duration minutes'),
                        if (call['notes'] != null &&
                            call['notes'].toString().trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('Notes: ${call['notes']}'),
                          ),
                        if (isPending && id.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      _declineCall(context, ref, id),
                                  child: const Text('Decline'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () =>
                                      _confirmCall(context, ref, id),
                                  child: const Text('Confirm'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
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
