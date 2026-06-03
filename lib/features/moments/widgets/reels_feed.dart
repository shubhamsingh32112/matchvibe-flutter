import 'package:flutter/material.dart';

import '../models/moments_models.dart';
import 'moment_card.dart';

/// Vertical reels feed — max ±1 video controllers via per-page keys + no KeepAlive.
class ReelsFeed extends StatefulWidget {
  const ReelsFeed({
    super.key,
    required this.items,
    this.onLoadMore,
    required this.onItemUpdated,
    this.onCreatorTap,
  });

  final List<MomentFeedItem> items;
  final VoidCallback? onLoadMore;
  final void Function(int index, MomentFeedItem item) onItemUpdated;
  final void Function(String creatorId)? onCreatorTap;

  @override
  State<ReelsFeed> createState() => _ReelsFeedState();
}

class _ReelsFeedState extends State<ReelsFeed> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Center(child: Text('No moments yet'));
    }

    return PageView.builder(
      controller: _controller,
      scrollDirection: Axis.vertical,
      allowImplicitScrolling: false,
      itemCount: widget.items.length,
      onPageChanged: (index) {
        setState(() => _currentIndex = index);
        if (widget.onLoadMore != null && index >= widget.items.length - 3) {
          widget.onLoadMore!();
        }
      },
      itemBuilder: (context, index) {
        final item = widget.items[index];
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
          playerInitDelay: initDelay,
          onItemUpdated: (updated) => widget.onItemUpdated(index, updated),
          onCreatorTap: widget.onCreatorTap == null
              ? null
              : () => widget.onCreatorTap!(item.creatorId),
        );
      },
    );
  }
}
