import 'package:flutter/material.dart';

import '../models/moments_models.dart';
import '../widgets/moment_card.dart';

class CreatorMomentViewerScreen extends StatelessWidget {
  const CreatorMomentViewerScreen({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  final List<MomentFeedItem> items;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _CreatorMomentPager(
            items: items,
            initialIndex: initialIndex,
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatorMomentPager extends StatefulWidget {
  const _CreatorMomentPager({
    required this.items,
    required this.initialIndex,
  });

  final List<MomentFeedItem> items;
  final int initialIndex;

  @override
  State<_CreatorMomentPager> createState() => _CreatorMomentPagerState();
}

class _CreatorMomentPagerState extends State<_CreatorMomentPager> {
  late final PageController _controller;
  late List<MomentFeedItem> _items;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      scrollDirection: Axis.vertical,
      allowImplicitScrolling: false,
      onPageChanged: (index) => setState(() => _currentIndex = index),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final distance = (index - _currentIndex).abs();
        if (distance > 1) {
          return ColoredBox(
            color: Colors.black,
            child: Image.network(
              item.media.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          );
        }
        final initDelay = distance == 0
            ? Duration.zero
            : Duration(milliseconds: 50 * distance);
        return MomentCard(
          key: ValueKey(item.id),
          item: item,
          playbackContext: 'profile',
          playerInitDelay: initDelay,
          onItemUpdated: (updated) {
            setState(() => _items[index] = updated);
          },
        );
      },
    );
  }
}
