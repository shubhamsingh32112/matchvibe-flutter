import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/features/home/providers/availability_provider.dart';

void main() {
  test('rejects stale overwrite for creator:status', () {
    final notifier = CreatorAvailabilityNotifier();
    notifier.updateSingle('c1', 'online', version: 3);
    notifier.updateSingle('c1', 'busy', version: 2);

    expect(notifier.state['c1'], CreatorAvailability.online);
  });

  test('rejects unversioned creator status updates', () {
    final notifier = CreatorAvailabilityNotifier();
    notifier.updateSingle('c1', 'online', version: 2);
    notifier.updateSingle('c1', 'busy');

    expect(notifier.state['c1'], CreatorAvailability.online);
  });

  test('rejects unversioned batch updates', () {
    final notifier = CreatorAvailabilityNotifier();
    notifier.updateSingle('c1', 'online', version: 2);
    notifier.updateBatch({'c1': 'busy'});

    expect(notifier.state['c1'], CreatorAvailability.online);
  });

  test('socket and hydration race keeps highest version', () {
    final notifier = CreatorAvailabilityNotifier();
    notifier.updateSingle('c1', 'online', version: 5);
    notifier.updateBatchV2({
      'c1': {'status': 'busy', 'version': 4},
      'c2': {'status': 'online', 'version': 1},
    });
    notifier.updateBatchV2({
      'c1': {'status': 'busy', 'version': 6},
    });

    expect(notifier.state['c1'], CreatorAvailability.busy);
    expect(notifier.state['c2'], CreatorAvailability.online);
  });

  test('duplicate online events do not regress state', () {
    final notifier = CreatorAvailabilityNotifier();
    notifier.updateSingle('c1', 'online', version: 10);
    notifier.updateSingle('c1', 'online', version: 10);
    notifier.updateSingle('c1', 'online', version: 9);

    expect(notifier.state['c1'], CreatorAvailability.online);
  });

  test('delayed offline replay is rejected', () {
    final notifier = CreatorAvailabilityNotifier();
    notifier.updateSingle('c1', 'busy', version: 12);
    notifier.updateSingle('c1', 'online', version: 11);

    expect(notifier.state['c1'], CreatorAvailability.busy);
  });

  test('seedFromApi does not overwrite live socket value', () {
    final notifier = CreatorAvailabilityNotifier();
    notifier.updateSingle('c1', 'online', version: 4);
    notifier.seedFromApi({'c1': CreatorAvailability.busy});

    expect(notifier.state['c1'], CreatorAvailability.online);
  });
}
