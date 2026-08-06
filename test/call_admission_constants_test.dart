import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/features/video/utils/call_admission_constants.dart';

void main() {
  test('kMinCoinsToCall matches backend MIN_COINS_TO_CALL default', () {
    expect(kMinCoinsToCall, 450);
  });

  group('meetsCallCoinAdmission', () {
    test('allows welcome free-call users with empty wallet', () {
      expect(
        meetsCallCoinAdmission(
          walletCoins: 0,
          welcomeFreeCallEligible: true,
          freeCallEnabled: true,
        ),
        isTrue,
      );
    });

    test('blocks free-call flag when freeCallEnabled is false', () {
      expect(
        meetsCallCoinAdmission(
          walletCoins: 0,
          welcomeFreeCallEligible: true,
          freeCallEnabled: false,
        ),
        isFalse,
      );
    });

    test('requires wallet coins when not free-call eligible', () {
      expect(
        meetsCallCoinAdmission(
          walletCoins: 449,
          welcomeFreeCallEligible: false,
        ),
        isFalse,
      );
      expect(
        meetsCallCoinAdmission(
          walletCoins: 450,
          welcomeFreeCallEligible: false,
        ),
        isTrue,
      );
    });

    test('does not treat intro seconds as wallet coins', () {
      // Caller must pass wallet only; 30 "intro seconds" must not unlock paid gate.
      expect(
        meetsCallCoinAdmission(
          walletCoins: 30,
          welcomeFreeCallEligible: false,
        ),
        isFalse,
      );
    });

    test('honors remote minCoinsToCall when provided', () {
      expect(
        meetsCallCoinAdmission(
          walletCoins: 100,
          welcomeFreeCallEligible: false,
          minCoinsToCall: 100,
        ),
        isTrue,
      );
    });
  });

  test('startUserCall uses meetsCallCoinAdmission preflight gate', () {
    final source = File(
      'lib/features/video/controllers/call_connection_controller.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> startUserCall');
    final end = source.indexOf('Future<void> startCreatorCallToUser');
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final block = source.substring(start, end);
    expect(block.contains('meetsCallCoinAdmission'), isTrue);
    expect(block.contains('welcomeFreeCallEligible'), isTrue);
    expect(block.contains("reason: 'preflight_low_coins'"), isTrue);
  });
}
