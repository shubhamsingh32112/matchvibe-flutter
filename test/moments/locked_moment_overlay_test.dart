import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/features/moments/models/moments_models.dart';
import 'package:zztherapy/features/moments/widgets/locked_moment_overlay.dart';

MomentFeedItem _lockedItem({String? accessReason}) {
  return MomentFeedItem(
    id: 'moment-1',
    creatorId: 'creator-1',
    creatorName: 'Ananya',
    creatorAvatarUrl: null,
    caption: null,
    media: const MediaPresentation(
      mediaType: 'image',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      locked: true,
      processingStatus: 'ready',
    ),
    createdAt: '2026-01-01',
    locked: true,
    accessReason: accessReason,
  );
}

void main() {
  testWidgets('LockedMomentOverlay shows VIP copy for VIP_ONLY', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LockedMomentOverlay(
            item: _lockedItem(accessReason: 'VIP_ONLY'),
            onUnlocked: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('VIP exclusive'), findsOneWidget);
    expect(find.text('Get VIP'), findsOneWidget);
    expect(find.text('Unlock Moments'), findsNothing);
    expect(find.text('Premium content'), findsNothing);
  });

  testWidgets('LockedMomentOverlay shows Premium copy for other reasons',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LockedMomentOverlay(
            item: _lockedItem(accessReason: 'PREMIUM_REQUIRED'),
            onUnlocked: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Premium content'), findsOneWidget);
    expect(find.text('Unlock Moments'), findsOneWidget);
    expect(find.text('VIP exclusive'), findsNothing);
    expect(find.text('Get VIP'), findsNothing);
  });
}
