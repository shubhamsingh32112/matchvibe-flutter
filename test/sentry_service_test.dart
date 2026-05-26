import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/core/services/sentry_error_classifier.dart';
import 'package:zztherapy/core/services/sentry_service.dart';

void main() {
  test('SentryService is disabled in debug/profile builds', () {
    expect(SentryService.isEnabled, isFalse);
  });

  group('SentryService breadcrumb throttle', () {
    test('second breadcrumb within 15s is throttled', () {
      const category = 'connectivity.dns';
      final now = DateTime(2026, 1, 1, 12, 0, 0);
      SentryService.recordBreadcrumbTimestampForTests(category, now);

      expect(
        SentryService.isBreadcrumbThrottled(category, now: now.add(const Duration(seconds: 5))),
        isTrue,
      );
      expect(
        SentryService.isBreadcrumbThrottled(category, now: now.add(const Duration(seconds: 16))),
        isFalse,
      );
    });
  });

  group('SentryErrorClassifier integration', () {
    test('shouldSuppressEvent drops restricted content', () {
      expect(
        SentryErrorClassifier.shouldSuppressEvent(
          Exception('Message contains restricted content'),
        ),
        isTrue,
      );
    });

    test('shouldReportCapture keeps backend DNS failures visible', () {
      expect(
        SentryErrorClassifier.shouldReportCapture(
          Exception("Failed host lookup: 'api.example.com'"),
        ),
        isTrue,
      );
    });
  });
}
