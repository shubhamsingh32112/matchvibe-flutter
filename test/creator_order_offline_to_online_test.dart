import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/features/home/providers/availability_provider.dart';
import 'package:zztherapy/features/home/providers/home_provider.dart';
import 'package:zztherapy/shared/models/creator_model.dart';

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
  test('offline to online moves creator to front of ordered ids', () {
    final notifier = CreatorOrderNotifier();
    final creators = [
      CreatorModel.fromJson(_creatorJson('1', availability: 'online')),
      CreatorModel.fromJson(_creatorJson('2', availability: 'offline')),
      CreatorModel.fromJson(_creatorJson('3', availability: 'offline')),
    ];
    notifier.syncCreators(
      creators,
      const {
        'fb-1': CreatorAvailability.online,
        'fb-2': CreatorAvailability.offline,
        'fb-3': CreatorAvailability.offline,
      },
      'userA',
    );
    expect(notifier.state.orderedIds.first, 'fb-1');

    notifier.updateBatch(const {'fb-2': CreatorAvailability.online});
    final ordered = notifier.resolveOrdered(creators);
    final uids = ordered.map((c) => c.firebaseUid).toList(growable: false);
    expect(uids.indexOf('fb-2'), lessThan(uids.indexOf('fb-3')));
    expect(uids.indexOf('fb-1'), lessThan(uids.indexOf('fb-3')));
    expect(uids.take(2).toSet(), containsAll(<String>['fb-1', 'fb-2']));
  });

  test('updateBatch is no-op before syncCreators; syncCreators fixes order', () {
    final notifier = CreatorOrderNotifier();
    final creators = [
      CreatorModel.fromJson(_creatorJson('1', availability: 'offline')),
      CreatorModel.fromJson(_creatorJson('2', availability: 'offline')),
    ];
    final availability = const {
      'fb-1': CreatorAvailability.offline,
      'fb-2': CreatorAvailability.online,
    };

    notifier.updateBatch(availability);
    expect(notifier.state.orderedIds, isEmpty);

    notifier.syncCreators(creators, availability, 'userA', force: true);
    final ordered = notifier.resolveOrdered(creators);
    expect(ordered.first.firebaseUid, 'fb-2');
  });
}
