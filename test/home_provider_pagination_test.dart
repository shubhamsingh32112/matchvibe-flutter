import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zztherapy/features/home/providers/availability_provider.dart';
import 'package:zztherapy/features/home/providers/home_provider.dart';
import 'package:zztherapy/shared/models/creator_model.dart';

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

Response<dynamic> _responseFor(
  String path,
  Map<String, dynamic> data, {
  int statusCode = 200,
}) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: path),
    statusCode: statusCode,
    data: data,
  );
}

void main() {
  test('creators pagination loads additional pages via notifier', () async {
    final container = ProviderContainer(
      overrides: [
        homeApiGetProvider.overrideWith((ref) {
          return (path) async {
            if (path.contains('/creator?page=1')) {
              return _responseFor(path, {
                'success': true,
                'data': {
                  'creators': [_creatorJson('1'), _creatorJson('2')],
                  'pagination': {
                    'page': 1,
                    'limit': 2,
                    'total': 3,
                    'totalPages': 2,
                  },
                },
              });
            }
            return _responseFor(path, {
              'success': true,
              'data': {
                'creators': [_creatorJson('3')],
                'pagination': {
                  'page': 2,
                  'limit': 2,
                  'total': 3,
                  'totalPages': 2,
                },
              },
            });
          };
        }),
      ],
    );
    addTearDown(container.dispose);

    final firstPage = await container.read(creatorsProvider.future);
    expect(firstPage.length, 2);
    expect(container.read(creatorsFeedMetaProvider).hasMore, isTrue);

    await container.read(creatorsProvider.notifier).loadMore();
    await Future<void>.delayed(Duration.zero);
    final loaded = container.read(creatorsProvider).valueOrNull ?? const <CreatorModel>[];
    expect(loaded.length, 3);
    expect(container.read(creatorsFeedMetaProvider).hasMore, isFalse);
  });

  test('creator order notifier updates only changed entries', () {
    final notifier = CreatorOrderNotifier();
    final creators = [
      CreatorModel.fromJson(_creatorJson('1')),
      CreatorModel.fromJson(_creatorJson('2')),
      CreatorModel.fromJson(_creatorJson('3')),
    ];
    notifier.syncCreators(creators, const {'fb-1': CreatorAvailability.online}, 'userA');
    final firstOrder = notifier.state.orderedIds;
    expect(firstOrder, containsAll(<String>['fb-1', 'fb-2', 'fb-3']));

    notifier.updateBatch(const {'fb-2': CreatorAvailability.online});
    final nextOrder = notifier.state.orderedIds;
    expect(nextOrder, contains('fb-2'));
    expect(nextOrder.length, 3);
  });
}
