import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/shared/widgets/paged_gallery_image_viewer.dart';

List<GalleryViewerItem> _items(int count) => [
  for (var i = 0; i < count; i++)
    GalleryViewerItem(
      imageUrl: 'https://example.com/gallery-$i.jpg',
      blurhash: null,
      heroTag: i == 0 ? 'hero-0' : null,
    ),
];

Widget _wrap(Widget child) {
  return MaterialApp(home: child);
}

void main() {
  testWidgets('shows page indicator at initialIndex', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PagedGalleryImageViewer(
          items: _items(3),
          initialIndex: 1,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('hides page indicator for single image', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PagedGalleryImageViewer(
          items: _items(1),
          initialIndex: 0,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('1 / 1'), findsNothing);
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('PageView uses PageScrollPhysics when not zoomed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        PagedGalleryImageViewer(
          items: _items(2),
          initialIndex: 0,
        ),
      ),
    );
    await tester.pump();

    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.physics, isA<PageScrollPhysics>());
    expect(pageView.allowImplicitScrolling, isTrue);
  });

  testWidgets('semantics label reflects photo index', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PagedGalleryImageViewer(
          items: _items(3),
          initialIndex: 2,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.bySemanticsLabel('Photo 3 of 3'),
      findsWidgets,
    );
  });

  testWidgets('clamps initialIndex to valid range', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PagedGalleryImageViewer(
          items: _items(2),
          initialIndex: 99,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('2 / 2'), findsOneWidget);
  });
}
