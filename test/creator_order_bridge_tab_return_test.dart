import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zztherapy/features/auth/providers/auth_provider.dart';
import 'package:zztherapy/features/home/providers/availability_provider.dart';
import 'package:zztherapy/features/home/providers/home_provider.dart';
import 'package:zztherapy/shared/models/creator_model.dart';
import 'package:zztherapy/shared/models/user_model.dart';

Map<String, dynamic> _creatorJson(String id, {String availability = 'offline'}) {
  return {
    'id': id,
    'userId': 'user-$id',
    'firebaseUid': 'fb-$id',
    'name': 'Creator $id',
    'about': 'About $id',
    'photo': 'https://example.com/$id.jpg',
    'galleryImages': const [],
    'categories': const ['Stress'],
    'price': 10,
    'availability': availability,
  };
}

void main() {
  test('creatorOrderBridge resyncs order when rebuilt after availability drift', () {
    final creators = [
      CreatorModel.fromJson(_creatorJson('1', availability: 'online')),
      CreatorModel.fromJson(_creatorJson('2', availability: 'offline')),
      CreatorModel.fromJson(_creatorJson('3', availability: 'offline')),
    ];

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          (ref) => AuthNotifier.testInitial(
            AuthState(
              user: const UserModel(id: 'fan-1', role: 'user', coins: 0),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final orderNotifier = container.read(creatorOrderProvider.notifier);
    final availabilityNotifier =
        container.read(creatorAvailabilityProvider.notifier);

    availabilityNotifier.updateSingle('fb-1', 'online', version: 1);
    availabilityNotifier.updateSingle('fb-2', 'offline', version: 1);
    availabilityNotifier.updateSingle('fb-3', 'offline', version: 1);

    orderNotifier.syncCreators(
      creators,
      container.read(creatorAvailabilityProvider),
      'fan-1',
    );
    expect(orderNotifier.state.orderedIds.first, 'fb-1');

    // Drift while bridge is "away": fb-2 goes online but order listener is inactive.
    availabilityNotifier.updateSingle('fb-2', 'online', version: 2);
    var ordered = orderNotifier.resolveOrdered(creators);
    expect(ordered.first.firebaseUid, 'fb-1');
    expect(ordered.map((c) => c.firebaseUid).contains('fb-2'), isTrue);
    expect(
      ordered.indexOf(creators[1]),
      greaterThan(ordered.indexOf(creators[0])),
    );

    // Returning to home recreates creatorOrderBridgeProvider.
    container.read(creatorOrderBridgeProvider);

    ordered = orderNotifier.resolveOrdered(creators);
    final topUids = ordered
        .take(2)
        .map((c) => c.firebaseUid)
        .whereType<String>()
        .toSet();
    expect(topUids, containsAll(<String>['fb-1', 'fb-2']));
  });
}
