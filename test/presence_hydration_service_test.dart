import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zztherapy/features/home/providers/home_provider.dart';
import 'package:zztherapy/features/home/services/presence_hydration_service.dart';

void main() {
  test('collectCreatorFirebaseUids parses /creator/uids response', () async {
    final container = ProviderContainer(
      overrides: [
        homeApiGetProvider.overrideWith((ref) {
          return (path) async {
            expect(path, '/creator/uids');
            return Response<dynamic>(
              requestOptions: RequestOptions(path: path),
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'firebaseUids': ['a', 'b', 'a', ''],
                },
              },
            );
          };
        }),
      ],
    );
    addTearDown(container.dispose);

    final svc = container.read(presenceHydrationServiceProvider);
    final ids = await svc.collectCreatorFirebaseUids();
    expect(ids.length, 2);
    expect(ids.toSet(), {'a', 'b'});
  });
}
