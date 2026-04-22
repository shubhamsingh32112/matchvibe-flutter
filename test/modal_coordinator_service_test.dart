import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/core/services/modal_coordinator_service.dart';

void main() {
  test('modal coordinator orders by priority and dedupes keys', () {
    final notifier = ModalCoordinatorNotifier();

    notifier.enqueue<void>(
      AppModalRequest<void>(
        id: 'low',
        priority: AppModalPriority.low,
        dedupeKey: 'same',
        present: (_, __) async {},
      ),
    );
    notifier.enqueue<void>(
      AppModalRequest<void>(
        id: 'critical',
        priority: AppModalPriority.critical,
        dedupeKey: 'critical',
        present: (_, __) async {},
      ),
    );
    notifier.enqueue<void>(
      AppModalRequest<void>(
        id: 'dup',
        priority: AppModalPriority.high,
        dedupeKey: 'same',
        present: (_, __) async {},
      ),
    );

    expect(notifier.state.queue.length, 2);
    expect(notifier.state.queue.first.id, 'critical');

    final first = notifier.takeNext();
    expect(first?.id, 'critical');
    notifier.complete(first!.id, null, dedupeKey: first.dedupeKey);
    expect(notifier.state.isPresenting, false);
    expect(notifier.state.presentedCount, 1);
  });

  test('modal coordinator keeps queue blocked until present future completes', () async {
    final notifier = ModalCoordinatorNotifier();
    final completer = Completer<void>();
    var completed = false;

    notifier.enqueue<void>(
      AppModalRequest<void>(
        id: 'slow',
        priority: AppModalPriority.high,
        dedupeKey: 'slow',
        present: (_, __) => completer.future,
        onCompleted: (_) {
          completed = true;
        },
      ),
    );
    notifier.enqueue<void>(
      AppModalRequest<void>(
        id: 'next',
        priority: AppModalPriority.normal,
        dedupeKey: 'next',
        present: (_, __) async {},
      ),
    );

    final first = notifier.takeNext();
    expect(first?.id, 'slow');
    expect(notifier.state.isPresenting, true);

    completer.complete();
    await completer.future;
    final firstRequest = first!;
    notifier.complete(firstRequest.id, null, dedupeKey: firstRequest.dedupeKey);
    firstRequest.onCompleted?.call(null);

    expect(completed, isTrue);
    expect(notifier.state.isPresenting, false);
    final second = notifier.takeNext();
    expect(second?.id, 'next');
  });
}
