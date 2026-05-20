import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/core/services/sentry_service.dart';

void main() {
  test('SentryService is disabled in debug/profile builds', () {
    expect(SentryService.isEnabled, isFalse);
  });
}
