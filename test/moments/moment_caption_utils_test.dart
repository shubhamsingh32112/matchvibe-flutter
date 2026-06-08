import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/features/moments/models/moments_models.dart';
import 'package:zztherapy/features/moments/providers/moments_providers.dart';
import 'package:zztherapy/features/moments/utils/moment_caption_utils.dart';

void main() {
  group('moment_caption_utils', () {
    test('extractFirstHashtag returns first tag', () {
      expect(
        extractFirstHashtag('Good vibes only ✨ #MorningVibes #Cozy'),
        '#MorningVibes',
      );
    });

    test('extractFirstHashtag returns null when absent', () {
      expect(extractFirstHashtag('No tags here'), isNull);
      expect(extractFirstHashtag(null), isNull);
    });

    test('captionWithoutHashtags strips hashtags', () {
      expect(
        captionWithoutHashtags('Rainy days #CozyVibes and tea'),
        'Rainy days and tea',
      );
    });
  });

  group('applyMediaFilter', () {
    final photo = MomentFeedItem(
      id: '1',
      creatorId: 'c1',
      creatorName: 'A',
      media: const MediaPresentation(
        mediaType: 'image',
        thumbnailUrl: 'https://example.com/a.jpg',
        locked: false,
        processingStatus: 'ready',
      ),
      createdAt: '',
      locked: false,
    );
    final video = MomentFeedItem(
      id: '2',
      creatorId: 'c2',
      creatorName: 'B',
      media: const MediaPresentation(
        mediaType: 'video',
        thumbnailUrl: 'https://example.com/b.jpg',
        locked: false,
        processingStatus: 'ready',
      ),
      createdAt: '',
      locked: false,
    );

    test('all returns every item', () {
      final result = applyMediaFilter([photo, video], MomentsMediaFilter.all);
      expect(result, [photo, video]);
    });

    test('photos returns images only', () {
      final result = applyMediaFilter([photo, video], MomentsMediaFilter.photos);
      expect(result, [photo]);
    });

    test('videos returns videos only', () {
      final result = applyMediaFilter([photo, video], MomentsMediaFilter.videos);
      expect(result, [video]);
    });
  });
}
