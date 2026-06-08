import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/moments_models.dart';
import '../utils/moment_owner_actions.dart';
import '../widgets/moment_card.dart';

class CreatorMomentViewerScreen extends ConsumerStatefulWidget {
  const CreatorMomentViewerScreen({
    super.key,
    required this.items,
    required this.initialIndex,
    this.allowOwnerDelete = false,
    this.creatorId,
  });

  final List<MomentFeedItem> items;
  final int initialIndex;
  final bool allowOwnerDelete;
  final String? creatorId;

  @override
  ConsumerState<CreatorMomentViewerScreen> createState() =>
      _CreatorMomentViewerScreenState();
}

class _CreatorMomentViewerScreenState
    extends ConsumerState<CreatorMomentViewerScreen> {
  late final PageController _controller;
  late List<MomentFeedItem> _items;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
    _currentIndex = widget.initialIndex.clamp(0, _items.length - 1);
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _deleteCurrent() async {
    if (_items.isEmpty) return;
    final item = _items[_currentIndex];
    final deleted = await deleteMomentWithRefresh(
      ref,
      context,
      item.id,
      creatorId: widget.creatorId ?? item.creatorId,
    );
    if (!deleted || !mounted) return;

    setState(() {
      _items.removeAt(_currentIndex);
      if (_items.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      if (_currentIndex >= _items.length) {
        _currentIndex = _items.length - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
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
          ),
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                if (widget.allowOwnerDelete)
                  IconButton(
                    tooltip: 'Delete post',
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                    onPressed: _deleteCurrent,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
