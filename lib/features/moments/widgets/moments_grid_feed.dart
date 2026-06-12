import 'package:flutter/material.dart';

import '../providers/moments_providers.dart';
import '../models/moments_models.dart';
import 'moments_add_center_button.dart';
import 'moments_grid_card.dart';
import '../screens/creator_moment_viewer_screen.dart';

class MomentsGridFeed extends StatefulWidget {
  const MomentsGridFeed({
    super.key,
    required this.items,
    required this.viewerItems,
    this.mediaFilter = MomentsMediaFilter.all,
    this.onLoadMore,
    required this.onItemUpdated,
    this.onCreatorTap,
    this.onReport,
    this.onAddMoment,
    this.reserveFabSpace = false,
    this.emptyMessage = 'No moments yet',
  });

  final List<MomentFeedItem> items;
  final List<MomentFeedItem> viewerItems;
  final MomentsMediaFilter mediaFilter;
  final VoidCallback? onLoadMore;
  final void Function(int index, MomentFeedItem item) onItemUpdated;
  final void Function(String creatorId)? onCreatorTap;
  final void Function(MomentFeedItem item)? onReport;
  final VoidCallback? onAddMoment;
  final bool reserveFabSpace;
  final String emptyMessage;

  @override
  State<MomentsGridFeed> createState() => _MomentsGridFeedState();
}

class _MomentsGridFeedState extends State<MomentsGridFeed> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.onLoadMore == null) return;
    final position = _scrollController.position;
    if (!position.hasPixels || !position.hasContentDimensions) return;
    if (position.pixels >= position.maxScrollExtent * 0.8) {
      widget.onLoadMore!();
    }
  }

  void _openViewer(int index) {
    final tapped = widget.items[index];
    final viewerIndex =
        widget.viewerItems.indexWhere((item) => item.id == tapped.id);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreatorMomentViewerScreen(
          items: widget.viewerItems,
          initialIndex: viewerIndex >= 0 ? viewerIndex : index,
          initialMediaFilter: widget.mediaFilter,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return MomentsFeedEmptyState(
        onAddMoment: widget.onAddMoment,
        message: widget.emptyMessage,
      );
    }

    final fabClearance = widget.reserveFabSpace
        ? MomentsPostReelFab.size + 24.0
        : 16.0;

    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(16, 8, 16, fabClearance),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        return MomentsGridCard(
          key: ValueKey(item.id),
          item: item,
          onTap: () => _openViewer(index),
          onViewCreator: widget.onCreatorTap == null
              ? null
              : () => widget.onCreatorTap!(item.creatorId),
          onReport: widget.onReport == null
              ? null
              : () => widget.onReport!(item),
        );
      },
    );
  }
}
