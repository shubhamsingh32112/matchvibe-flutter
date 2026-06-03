import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/core/services/video_playback_metrics_reporter.dart';

void main() {
  tearDown(() {
    VideoPlaybackMetricsReporter.debugSet(
      VideoPlaybackMetricsReporter.forTest(postOverride: (_, __) async {}),
    );
  });

  test('always samples player_error and token_refresh_fail', () {
    final reporter = VideoPlaybackMetricsReporter.forTest(skipPerfSampling: true);
    VideoPlaybackMetricsReporter.debugSet(reporter);

    reporter.record(event: 'player_error', context: 'reels', errorClass: 'test');
    reporter.record(event: 'token_refresh_fail', context: 'story', reason: '503');
    reporter.record(event: 'startup', context: 'reels', valueMs: 100);

    expect(reporter.bufferLength, 2);
  });

  test('flush clears buffer and posts batch', () async {
    var postCount = 0;
    List<Map<String, dynamic>> lastSamples = [];
    final reporter = VideoPlaybackMetricsReporter.forTest(
      postOverride: (path, data) async {
        postCount += 1;
        expect(path, '/metrics/video-playback');
        lastSamples = (data['samples'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      },
    );
    VideoPlaybackMetricsReporter.debugSet(reporter);

    for (var i = 0; i < 3; i++) {
      reporter.record(event: 'player_error', context: 'reels');
    }
    await reporter.flush();
    expect(postCount, 1);
    expect(lastSamples.length, 3);
    expect(reporter.bufferLength, 0);
  });

  test('disabled reporter drops all events', () {
    final reporter = VideoPlaybackMetricsReporter.forTest(enabled: false);
    VideoPlaybackMetricsReporter.debugSet(reporter);
    reporter.record(event: 'player_error', context: 'reels');
    expect(reporter.bufferLength, 0);
  });

  test('error events use weight 1', () async {
    Map<String, dynamic>? firstSample;
    final reporter = VideoPlaybackMetricsReporter.forTest(
      postOverride: (_, data) async {
        firstSample = (data['samples'] as List).first as Map<String, dynamic>;
      },
    );
    VideoPlaybackMetricsReporter.debugSet(reporter);
    reporter.record(event: 'player_error', context: 'reels');
    await reporter.flush();
    expect(firstSample!['weight'], 1);
  });
}
