import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    'availability': 'busy',
  };
}

Response<dynamic> _responseFor(String path, Map<String, dynamic> data) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
    data: data,
  );
}

class _StressHomeFeed extends ConsumerStatefulWidget {
  const _StressHomeFeed();

  @override
  ConsumerState<_StressHomeFeed> createState() => _StressHomeFeedState();
}

class _StressHomeFeedState extends ConsumerState<_StressHomeFeed> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    if (_controller.position.extentAfter > 400) return;
    final meta = ref.read(creatorsFeedMetaProvider);
    if (meta.hasMore && !meta.isLoadingMore) {
      ref.read(creatorsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final creatorsAsync = ref.watch(creatorsProvider);
    ref.watch(creatorOrderProvider);

    return creatorsAsync.when(
      data: (creators) {
        final ordered = ref.read(creatorOrderProvider.notifier).resolveOrdered(creators);
        return ListView.builder(
          controller: _controller,
          itemExtent: 64,
          itemCount: ordered.length,
          itemBuilder: (_, index) => Text(
            ordered[index].id,
            key: ValueKey<String>('creator-${ordered[index].id}'),
          ),
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const Text('error'),
    );
  }
}

void main() {
  testWidgets('availability burst while scrolling keeps feed unique and paginates', (
    tester,
  ) async {
    final page1 = List.generate(20, (i) => _creatorJson('${i + 1}'));
    final page2 = List.generate(20, (i) => _creatorJson('${i + 21}'));
    final page3 = List.generate(5, (i) => _creatorJson('${i + 41}'));

    final container = ProviderContainer(
      overrides: [
        homeApiGetProvider.overrideWith((ref) {
          return (path) async {
            if (path.contains('/creator/feed?page=1')) {
              return _responseFor(path, {
                'success': true,
                'data': {
                  'creators': page1,
                  'pagination': {
                    'page': 1,
                    'limit': 20,
                    'total': 45,
                    'totalPages': 3,
                  },
                },
              });
            }
            if (path.contains('/creator/feed?page=2')) {
              return _responseFor(path, {
                'success': true,
                'data': {
                  'creators': page2,
                  'pagination': {
                    'page': 2,
                    'limit': 20,
                    'total': 45,
                    'totalPages': 3,
                  },
                },
              });
            }
            return _responseFor(path, {
              'success': true,
              'data': {
                'creators': page3,
                'pagination': {
                  'page': 3,
                  'limit': 20,
                  'total': 45,
                  'totalPages': 3,
                },
              },
            });
          };
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: _StressHomeFeed()),
        ),
      ),
    );

    final firstPage = await container.read(creatorsProvider.future);
    container.read(creatorOrderProvider.notifier).syncCreators(
      firstPage,
      container.read(creatorAvailabilityProvider),
      'stress-user',
    );
    await tester.pumpAndSettle();

    for (var burst = 0; burst < 30; burst++) {
      final updates = <String, CreatorAvailability>{};
      for (var i = 1; i <= 45; i++) {
        if ((i + burst) % 5 == 0) {
          updates['fb-$i'] = (i + burst) % 2 == 0
              ? CreatorAvailability.online
              : CreatorAvailability.busy;
        }
      }
      container.read(creatorAvailabilityProvider.notifier).updateBatch(
            updates.map((key, value) => MapEntry(
                  key,
                  value == CreatorAvailability.online ? 'online' : 'busy',
                )),
          );
      container.read(creatorOrderProvider.notifier).updateBatch(updates);
      await tester.fling(find.byType(ListView), const Offset(0, -1200), 2000);
      await tester.pump(const Duration(milliseconds: 120));
      final currentCreators =
          container.read(creatorsProvider).valueOrNull ?? const <CreatorModel>[];
      container.read(creatorOrderProvider.notifier).syncCreators(
            currentCreators,
            container.read(creatorAvailabilityProvider),
            'stress-user',
          );
    }
    await tester.pumpAndSettle();

    final creators = container.read(creatorsProvider).valueOrNull ?? const <CreatorModel>[];
    final uniqueIds = creators.map((c) => c.id).toSet();
    expect(creators.length, 45);
    expect(uniqueIds.length, creators.length);

    final orderedIds = container.read(creatorOrderProvider).orderedIds;
    expect(orderedIds.toSet().length, orderedIds.length);
    expect(container.read(creatorsFeedMetaProvider).hasMore, isFalse);
  });
}
