import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/features/moments/models/moments_models.dart';
import 'package:zztherapy/features/moments/widgets/moment_action_rail.dart';

MomentFeedItem _sampleItem({
  bool isLiked = false,
  int likesCount = 12500,
  int commentsCount = 1200,
  bool isFollowing = false,
}) {
  return MomentFeedItem(
    id: 'm1',
    creatorId: 'c1',
    creatorName: 'Aisha Verma',
    creatorAvatarUrl: 'https://example.com/avatar.jpg',
    media: const MediaPresentation(
      mediaType: 'image',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      locked: false,
      processingStatus: 'ready',
    ),
    createdAt: DateTime.now().toIso8601String(),
    locked: false,
    isFollowing: isFollowing,
    likesCount: likesCount,
    commentsCount: commentsCount,
    isLiked: isLiked,
  );
}

void main() {
  testWidgets('MomentActionRail shows follow, like, comment, and share actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MomentActionRail(
            item: _sampleItem(),
            onLike: () {},
            onComment: () {},
            onShare: () {},
          ),
        ),
      ),
    );

    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('12.5K'), findsOneWidget);
    expect(find.text('1.2K'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });

  testWidgets('MomentActionRail shows filled heart when liked', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MomentActionRail(
            item: _sampleItem(isLiked: true),
            onLike: () {},
            onComment: () {},
            onShare: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });
}
