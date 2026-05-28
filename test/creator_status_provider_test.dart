import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/core/services/socket_service.dart';
import 'package:zztherapy/features/auth/providers/auth_provider.dart';
import 'package:zztherapy/features/creator/providers/creator_status_provider.dart'
    as creator_self;
import 'package:zztherapy/features/home/providers/availability_provider.dart';
import 'package:zztherapy/shared/models/user_model.dart';

/// Test double: production [SocketService] with a fixed connection flag.
class FakeSocketService extends SocketService {
  FakeSocketService({this.connected = false});
  final bool connected;

  @override
  bool get isConnected => connected;
}

UserModel _creatorUser() => const UserModel(
      id: 'mongo-1',
      role: 'creator',
      email: 'c@test.com',
      coins: 0,
    );

void main() {
  test('creator shows online when SocketService connected and map empty', () {
    final container = ProviderContainer(
      overrides: [
        socketServiceProvider.overrideWithValue(
          FakeSocketService(connected: true),
        ),
        authProvider.overrideWith(
          (ref) => AuthNotifier.testInitial(
            AuthState(user: _creatorUser()),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(creator_self.creatorStatusProvider),
      creator_self.CreatorStatus.online,
    );
  });

  test('updateFromSocketConnection true sets online when socket up', () {
    final container = ProviderContainer(
      overrides: [
        socketServiceProvider.overrideWithValue(
          FakeSocketService(connected: true),
        ),
        authProvider.overrideWith(
          (ref) => AuthNotifier.testInitial(
            AuthState(user: _creatorUser()),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(creator_self.creatorStatusProvider.notifier)
        .updateFromSocketConnection(false);
    expect(
      container.read(creator_self.creatorStatusProvider),
      creator_self.CreatorStatus.offline,
    );

    container
        .read(creator_self.creatorStatusProvider.notifier)
        .updateFromSocketConnection(true);
    expect(
      container.read(creator_self.creatorStatusProvider),
      creator_self.CreatorStatus.online,
    );
  });

  test('updateFromSocketConnection false sets offline', () {
    final container = ProviderContainer(
      overrides: [
        socketServiceProvider.overrideWithValue(
          FakeSocketService(connected: false),
        ),
        authProvider.overrideWith(
          (ref) => AuthNotifier.testInitial(
            AuthState(user: _creatorUser()),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(creator_self.creatorStatusProvider.notifier)
        .updateFromSocketConnection(false);
    expect(
      container.read(creator_self.creatorStatusProvider),
      creator_self.CreatorStatus.offline,
    );
  });
}
