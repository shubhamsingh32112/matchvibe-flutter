import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/features/moments/models/moments_models.dart';

void main() {
  test('MediaPresentation parses expiresAtMs from feed JSON', () {
    final media = MediaPresentation.fromJson({
      'mediaType': 'video',
      'thumbnailUrl': 'https://example.com/t.jpg',
      'playbackUrl': 'https://example.com/v.m3u8',
      'expiresAtMs': 1_700_000_000_000,
      'locked': false,
      'processingStatus': 'ready',
    });
    expect(media.expiresAtMs, 1_700_000_000_000);
    expect(media.isVideo, isTrue);
  });
}
