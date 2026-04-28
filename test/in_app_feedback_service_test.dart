import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/core/services/in_app_feedback_service.dart';

void main() {
  test('dedupes identical message keys within dedupe window', () async {
    var nowMs = 1;
    var hapticCount = 0;

    final service = InAppFeedbackService.test(
      nowMs: () => nowMs,
      haptic: () async {
        hapticCount++;
      },
      isMobile: () => true,
    );

    service.notifyChatMessage(dedupeKey: 'chat_message:1');
    service.notifyChatMessage(dedupeKey: 'chat_message:1');

    expect(hapticCount, 1);

    // Still within dedupe window
    nowMs += 5000;
    service.notifyChatMessage(dedupeKey: 'chat_message:1');
    expect(hapticCount, 1);
  });

  test('rate-limits different keys within cooldown', () async {
    var nowMs = 1;
    var hapticCount = 0;

    final service = InAppFeedbackService.test(
      nowMs: () => nowMs,
      haptic: () async {
        hapticCount++;
      },
      isMobile: () => true,
    );

    service.notifyChatMessage(dedupeKey: 'chat_message:a');
    expect(hapticCount, 1);

    // Different key, but within cooldown => no second haptic
    nowMs += 200;
    service.notifyChatMessage(dedupeKey: 'chat_message:b');
    expect(hapticCount, 1);

    // After cooldown => allows haptic
    nowMs += 2000;
    service.notifyChatMessage(dedupeKey: 'chat_message:c');
    expect(hapticCount, 2);
  });
}

