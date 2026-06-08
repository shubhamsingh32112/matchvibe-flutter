import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/app_toast.dart';
import '../providers/vip_provider.dart';

Future<void> showScheduleCallSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String creatorId,
  required String creatorName,
}) async {
  DateTime selected = DateTime.now().add(const Duration(hours: 1));
  final notesController = TextEditingController();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Schedule call with $creatorName',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date & time'),
                  subtitle: Text(
                    '${selected.day}/${selected.month}/${selected.year} '
                    '${selected.hour.toString().padLeft(2, '0')}:'
                    '${selected.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selected,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 7)),
                    );
                    if (date == null) return;
                    if (!context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(selected),
                    );
                    if (time == null) return;
                    setModalState(() {
                      selected = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  },
                ),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    try {
                      await ref.read(vipApiServiceProvider).scheduleCall(
                            creatorId: creatorId,
                            scheduledAt: selected.toUtc(),
                            notes: notesController.text,
                          );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        AppToast.showSuccess(
                          context,
                          'Call scheduled — awaiting creator confirmation',
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AppToast.showError(
                          context,
                          'Could not schedule call',
                        );
                      }
                    }
                  },
                  child: const Text('Schedule'),
                ),
              ],
            );
          },
        ),
      );
    },
  );
  notesController.dispose();
}
