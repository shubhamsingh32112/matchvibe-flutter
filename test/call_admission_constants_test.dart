import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/features/video/utils/call_admission_constants.dart';

void main() {
  test('kMinCoinsToCall matches backend MIN_COINS_TO_CALL default', () {
    expect(kMinCoinsToCall, 10);
  });

  test('startUserCall uses kMinCoinsToCall preflight gate', () {
    final source = File(
      'lib/features/video/controllers/call_connection_controller.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> startUserCall');
    final end = source.indexOf('Future<void> startCreatorCallToUser');
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final block = source.substring(start, end);
    expect(block.contains('kMinCoinsToCall'), isTrue);
    expect(block.contains('spendable < kMinCoinsToCall'), isTrue);
    expect(block.contains("reason: 'preflight_low_coins'"), isTrue);
  });
}
