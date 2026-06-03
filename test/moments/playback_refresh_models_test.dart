import 'package:flutter_test/flutter_test.dart';

import 'package:zztherapy/features/moments/models/playback_refresh_models.dart';

void main() {
  test('PlaybackRefreshException identifies denied vs degraded', () {
    final denied = PlaybackRefreshException('locked', statusCode: 403, code: 'PLAYBACK_DENIED');
    final degraded = PlaybackRefreshException(
      'unavailable',
      statusCode: 503,
      code: 'PLAYBACK_SIGNING_UNAVAILABLE',
    );

    expect(denied.isDenied, isTrue);
    expect(denied.isDegraded, isFalse);
    expect(degraded.isDegraded, isTrue);
  });

  test('PlaybackRefreshResult parses expiresAtMs', () {
    const result = PlaybackRefreshResult(
      playbackUrl: 'https://example.com/video.m3u8',
      expiresAtMs: 1_700_000_000_000,
    );
    expect(result.playbackUrl, contains('.m3u8'));
    expect(result.expiresAtMs, greaterThan(0));
  });
}
