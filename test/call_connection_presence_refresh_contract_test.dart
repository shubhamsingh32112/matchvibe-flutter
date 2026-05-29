import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('call controller triggers creator presence refresh fallback on call end', () async {
    final src = await File(
      'lib/features/video/controllers/call_connection_controller.dart',
    ).readAsString();

    expect(src.contains('_refreshCreatorOwnPresenceAfterCallEnd()'), isTrue);
    expect(
      src.contains("refreshPresence(reason: 'call_ended')"),
      isTrue,
    );
  });

  test('incoming creator accept tracks creator uid for end-call fallback', () async {
    final src = await File(
      'lib/features/video/controllers/call_connection_controller.dart',
    ).readAsString();

    expect(
      src.contains('_activeCreatorFirebaseUid = _ref.read(authProvider).firebaseUser?.uid;'),
      isTrue,
    );
  });
}
