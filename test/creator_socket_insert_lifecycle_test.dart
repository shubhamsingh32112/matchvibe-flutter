import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zztherapy/features/auth/providers/auth_provider.dart';
import 'package:zztherapy/features/home/providers/availability_provider.dart';
import 'package:zztherapy/features/home/providers/home_provider.dart';
import 'package:zztherapy/shared/models/creator_model.dart';
import 'package:zztherapy/shared/models/user_model.dart';

Map<String, dynamic> _creatorJson(String id, {String availability = 'online'}) {
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

Response<dynamic> _emptyFeedResponse(String path) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
    data: {
      'success': true,
      'data': {
        'creators': const [],
        'pagination': {'page': 1, 'limit': 20, 'total': 0, 'totalPages': 0},
      },
    },
  );
}

void main() {
  final testAuthState = AuthState(
    user: const UserModel(id: 'test-user', coins: 0, role: 'user'),
  );

  test('socket-inserted creator removed from feed on offline', () async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          (ref) => AuthNotifier.testInitial(testAuthState),
        ),
        homeApiGetProvider.overrideWith(
          (ref) => (path) async => _emptyFeedResponse(path),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(creatorsProvider.future);
    final notifier = container.read(creatorsProvider.notifier);
    notifier.debugSeedFeedState(
      items: [CreatorModel.fromJson(_creatorJson('a'))],
      socketInsertedUids: {'fb-a'},
    );

    notifier.handlePresenceTransitionForFeed(
      firebaseUid: 'fb-a',
      status: 'offline',
    );

    expect(notifier.feedItemsForTest(), isEmpty);
    expect(notifier.socketInsertedFirebaseUidsForTest(), isEmpty);
  });

  test('paginated creator stays in feed on offline', () async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          (ref) => AuthNotifier.testInitial(testAuthState),
        ),
        homeApiGetProvider.overrideWith(
          (ref) => (path) async => _emptyFeedResponse(path),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(creatorsProvider.future);
    final notifier = container.read(creatorsProvider.notifier);
    notifier.debugSeedFeedState(
      items: [CreatorModel.fromJson(_creatorJson('b', availability: 'offline'))],
    );

    notifier.handlePresenceTransitionForFeed(
      firebaseUid: 'fb-b',
      status: 'offline',
    );

    expect(notifier.feedItemsForTest().length, 1);
    expect(notifier.socketInsertedFirebaseUidsForTest(), isEmpty);
  });

  test('socket-inserted creator remains in feed on on_call', () async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          (ref) => AuthNotifier.testInitial(testAuthState),
        ),
        homeApiGetProvider.overrideWith(
          (ref) => (path) async => _emptyFeedResponse(path),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(creatorsProvider.future);
    final notifier = container.read(creatorsProvider.notifier);
    notifier.debugSeedFeedState(
      items: [CreatorModel.fromJson(_creatorJson('c'))],
      socketInsertedUids: {'fb-c'},
    );

    notifier.handlePresenceTransitionForFeed(
      firebaseUid: 'fb-c',
      status: 'on_call',
    );

    expect(notifier.feedItemsForTest().length, 1);
    expect(notifier.socketInsertedFirebaseUidsForTest(), contains('fb-c'));
  });
}
