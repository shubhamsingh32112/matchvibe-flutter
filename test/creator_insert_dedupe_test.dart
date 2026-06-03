import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zztherapy/features/auth/providers/auth_provider.dart';
import 'package:zztherapy/features/home/providers/home_provider.dart';
import 'package:zztherapy/features/home/services/home_feed_metrics.dart';
import 'package:zztherapy/shared/models/user_model.dart';

Map<String, dynamic> _creatorJson(String id) {
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
    'availability': 'online',
  };
}

void main() {
  final testAuthState = AuthState(
    user: const UserModel(id: 'test-user', coins: 0, role: 'user'),
  );

  setUp(HomeFeedMetrics.resetForTest);

  test('parallel insert and ensure produce one feed row', () async {
    var fetchCount = 0;
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          (ref) => AuthNotifier.testInitial(testAuthState),
        ),
        homeApiGetProvider.overrideWith((ref) {
          return (path) async {
            if (path.startsWith('/creator/feed')) {
              return Response<dynamic>(
                requestOptions: RequestOptions(path: path),
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'creators': const [],
                    'pagination': {
                      'page': 1,
                      'limit': 20,
                      'total': 0,
                      'totalPages': 0,
                    },
                  },
                },
              );
            }
            if (path.contains('/creator/by-firebase-uid/fb-race')) {
              fetchCount++;
              await Future<void>.delayed(const Duration(milliseconds: 20));
              return Response<dynamic>(
                requestOptions: RequestOptions(path: path),
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {'creator': _creatorJson('race')},
                },
              );
            }
            throw UnimplementedError(path);
          };
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(creatorsProvider.future);
    final notifier = container.read(creatorsProvider.notifier);

    await Future.wait([
      Future<void>(() async {
        notifier.insertOrUpdateFromStatusEvent(
          firebaseUid: 'fb-race',
          status: 'online',
          creatorSummary: _creatorJson('race'),
        );
      }),
      Future<void>(() async {
        await notifier.ensureCreatorInFeedByFirebaseUid('fb-race');
      }),
    ]);

    expect(notifier.feedItemsForTest().length, 1);
    expect(
      notifier.feedItemsForTest().single.firebaseUid,
      'fb-race',
    );
    expect(fetchCount, lessThanOrEqualTo(1));
  });

  test('reconnect storm: many parallel inserts yield one row', () async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          (ref) => AuthNotifier.testInitial(testAuthState),
        ),
        homeApiGetProvider.overrideWith(
          (ref) => (path) async => Response<dynamic>(
            requestOptions: RequestOptions(path: path),
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'creators': const [],
                'pagination': {
                  'page': 1,
                  'limit': 20,
                  'total': 0,
                  'totalPages': 0,
                },
              },
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(creatorsProvider.future);
    final notifier = container.read(creatorsProvider.notifier);

    await Future.wait(
      List.generate(10, (_) {
        return Future<void>(() {
          notifier.insertOrUpdateFromStatusEvent(
            firebaseUid: 'fb-storm',
            status: 'online',
            creatorSummary: _creatorJson('storm'),
          );
        });
      }),
    );

    expect(notifier.feedItemsForTest().length, 1);
    expect(HomeFeedMetrics.socketInsertionsTotal, greaterThanOrEqualTo(1));
  });
}
