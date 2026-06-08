import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/features/moments/models/moments_models.dart';
import 'package:zztherapy/features/moments/widgets/moments_grid_card.dart';

MomentFeedItem _sampleItem({String? caption, bool isVideo = false}) {
  return MomentFeedItem(
    id: 'moment-1',
    creatorId: 'creator-1',
    creatorName: 'Ananya',
    creatorAvatarUrl: null,
    caption: caption,
    media: MediaPresentation(
      mediaType: isVideo ? 'video' : 'image',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      locked: false,
      processingStatus: 'ready',
    ),
    createdAt: '2026-01-01',
    locked: false,
  );
}

void main() {
  testWidgets('MomentsGridCard shows caption, hashtag, and verified icon',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 320,
            child: MomentsGridCard(item: _sampleItem(caption: 'Good vibes #MorningVibes')),
          ),
        ),
      ),
    );

    expect(find.text('Good vibes'), findsOneWidget);
    expect(find.text('#MorningVibes'), findsOneWidget);
    expect(find.text('Ananya'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('MomentsGridCard shows video media icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 320,
            child: MomentsGridCard(item: _sampleItem(isVideo: true)),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
  });
}
