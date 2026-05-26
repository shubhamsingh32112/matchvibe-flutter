import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:zztherapy/core/services/sentry_error_classifier.dart';
import 'package:zztherapy/features/chat/exceptions/chat_send_exceptions.dart';

void main() {
  group('SentryErrorClassifier.classifyError', () {
    test('RestrictedContentException drops', () {
      expect(
        SentryErrorClassifier.classifyError(
          const RestrictedContentException(),
        ),
        SentryErrorDisposition.drop,
      );
    });

    test('PlayerInterruptedException drops', () {
      expect(
        SentryErrorClassifier.classifyError(
          PlayerInterruptedException('aborted'),
        ),
        SentryErrorDisposition.drop,
      );
    });

    test('allowlisted DNS host samples', () {
      expect(
        SentryErrorClassifier.classifyError(
          SocketException("Failed host lookup: 'chat.stream-io-api.com'"),
        ),
        SentryErrorDisposition.sample,
      );
    });

    test('unknown DNS host reports', () {
      expect(
        SentryErrorClassifier.classifyError(
          SocketException("Failed host lookup: 'prestigeinteriordesign.com'"),
        ),
        SentryErrorDisposition.report,
      );
    });

    test('unparseable DNS host reports (fail open)', () {
      expect(
        SentryErrorClassifier.classifyError(
          const SocketException('Failed host lookup'),
        ),
        SentryErrorDisposition.report,
      );
    });

    test('ref after dispose reports via opaque message', () {
      expect(
        SentryErrorClassifier.classifyError(
          StateError('Cannot use "ref" after the widget was disposed.'),
        ),
        SentryErrorDisposition.report,
      );
    });

    test('opaque IceTrickle abort samples', () {
      expect(
        SentryErrorClassifier.classifyError(
          Exception(
            'TwirpError: connection abort during IceTrickle to sfu-aws-m1.stream-io-video.com',
          ),
        ),
        SentryErrorDisposition.sample,
      );
    });
  });

  group('SentryErrorClassifier.shouldSample', () {
    test('is deterministic for same fingerprint', () {
      const fp = 'SocketException|chat.stream-io-api.com';
      final first = SentryErrorClassifier.shouldSample(fp, 0.02);
      final second = SentryErrorClassifier.shouldSample(fp, 0.02);
      expect(first, second);
    });

    test('respects rate bounds', () {
      expect(SentryErrorClassifier.shouldSample('a', 1.0), isTrue);
      expect(SentryErrorClassifier.shouldSample('a', 0.0), isFalse);
    });
  });

  group('SentryErrorClassifier.extractHostFromSocketMessage', () {
    test('parses quoted host', () {
      expect(
        SentryErrorClassifier.extractHostFromSocketMessage(
          "Failed host lookup: 'chat.stream-io-api.com' (OS Error: ...)",
        ),
        'chat.stream-io-api.com',
      );
    });

    test('returns null for malformed message', () {
      expect(
        SentryErrorClassifier.extractHostFromSocketMessage('connection reset'),
        isNull,
      );
    });
  });
}
