import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/features/moments/models/moments_models.dart';
import 'package:zztherapy/features/moments/widgets/reels_feed.dart';

bool shouldMountMomentCard(int index, int currentIndex) {
  return (index - currentIndex).abs() <= 1;
}

void main() {
  test('windowing helper mounts at most 3 pages around current index', () {
    const currentIndex = 5;
    var mounted = 0;
    for (var i = 0; i < 20; i++) {
      if (shouldMountMomentCard(i, currentIndex)) mounted += 1;
    }
    expect(mounted, 3);
  });

  testWidgets('ReelsFeed shows placeholder when empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReelsFeed(
          items: [],
          onItemUpdated: _noopUpdate,
        ),
      ),
    );
    expect(find.text('No moments yet'), findsOneWidget);
  });
}

void _noopUpdate(int index, MomentFeedItem item) {}
