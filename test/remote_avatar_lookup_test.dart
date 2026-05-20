import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/features/video/utils/remote_avatar_lookup.dart';

void main() {
  group('resolveAvatarUrlFromRow', () {
    test('prefers callPhoto from nested avatar', () {
      final url = resolveAvatarUrlFromRow({
        'avatar': {
          'avatarUrls': {
            'callPhoto': 'https://cdn.example/call.jpg',
            'md': 'https://cdn.example/md.jpg',
          },
        },
      });
      expect(url, 'https://cdn.example/call.jpg');
    });

    test('falls back to md when callPhoto missing', () {
      final url = resolveAvatarUrlFromRow({
        'avatar': {
          'avatarUrls': {
            'md': 'https://cdn.example/md.jpg',
          },
        },
      });
      expect(url, 'https://cdn.example/md.jpg');
    });

    test('falls back to legacy photo string', () {
      final url = resolveAvatarUrlFromRow({
        'photo': 'https://legacy.example/photo.jpg',
      });
      expect(url, 'https://legacy.example/photo.jpg');
    });
  });

  group('extractCallerFirebaseUidFromCallId', () {
    test('parses initiator uid from deterministic call id', () {
      expect(
        extractCallerFirebaseUidFromCallId('abc123_creatorMongo_1710000000'),
        'abc123',
      );
    });
  });

  test('startUserCall passes initiatorImageUrl to initiateCallToMember', () {
    final source = File(
      'lib/features/video/controllers/call_connection_controller.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> startUserCall');
    final end = source.indexOf('Future<void> startCreatorCallToUser');
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final block = source.substring(start, end);
    expect(block.contains('initiatorImageUrl: callerImage'), isTrue);
    expect(block.contains("initiatedByRole: 'user'"), isTrue);
  });

  test('lookupIncomingCallerAvatar uses role-aware paths in listener', () {
    final source = File(
      'lib/features/video/widgets/incoming_call_listener.dart',
    ).readAsStringSync();
    expect(source.contains('lookupIncomingCallerAvatar'), isTrue);
    expect(source.contains('lookupAvatarFromUserList'), isFalse);
    expect(source.contains('_lookupAvatarFromCreatorsList'), isFalse);
  });
}
