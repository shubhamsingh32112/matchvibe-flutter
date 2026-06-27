import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/theme/moments_premium_page_tokens.dart';
import '../providers/moments_providers.dart';
import '../models/moments_models.dart';
import '../utils/moments_paywall.dart';
import 'moments_add_center_button.dart';
import 'moments_grid_card.dart';
import '../screens/creator_moment_viewer_screen.dart';

class MomentsGridFeed extends ConsumerStatefulWidget {
  const MomentsGridFeed({
    super.key,
    required this.items,
    required this.viewerItems,
    this.previewEndIndex = 0,
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
  final int previewEndIndex;
  final MomentsMediaFilter mediaFilter;
  final VoidCallback? onLoadMore;
  final void Function(int index, MomentFeedItem item) onItemUpdated;
  final void Function(String creatorId)? onCreatorTap;
  final void Function(MomentFeedItem item)? onReport;
  final VoidCallback? onAddMoment;
  final bool reserveFabSpace;
  final String emptyMessage;

  @override
  ConsumerState<MomentsGridFeed> createState() => _MomentsGridFeedState();
}

class _MomentsGridFeedState extends ConsumerState<MomentsGridFeed> {
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

  bool get _showPreviewDivider {
    final access = ref.watch(momentsAccessStateProvider);
    return access.showPremiumUi &&
        access.showPaywall &&
        widget.previewEndIndex > 0 &&
        widget.previewEndIndex < widget.items.length;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(momentsPremiumExpiryWatcherProvider);

    if (widget.items.isEmpty) {
      return MomentsFeedEmptyState(
        onAddMoment: widget.onAddMoment,
        message: widget.emptyMessage,
      );
    }

    final access = ref.watch(momentsAccessStateProvider);
    final showFloatingCta =
        access.showPremiumUi && widget.items.any((i) => i.locked);

    final fabClearance = widget.reserveFabSpace
        ? MomentsPostReelFab.size + 24.0
        : 16.0;
    final ctaClearance = showFloatingCta ? 56.0 : 0.0;

    final previewItems = widget.previewEndIndex > 0
        ? widget.items.take(widget.previewEndIndex).toList()
        : <MomentFeedItem>[];
    final restItems = widget.previewEndIndex > 0
        ? widget.items.skip(widget.previewEndIndex).toList()
        : widget.items;
    final showDivider = _showPreviewDivider;

    SliverGrid _gridSliver(List<MomentFeedItem> gridItems, int indexOffset) {
      return SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.62,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = gridItems[index];
            final itemIndex = indexOffset + index;
            return MomentsGridCard(
              key: ValueKey(item.id),
              item: item,
              onTap: () => _openViewer(itemIndex),
              onViewCreator: widget.onCreatorTap == null
                  ? null
                  : () => widget.onCreatorTap!(item.creatorId),
              onReport: widget.onReport == null
                  ? null
                  : () => widget.onReport!(item),
            );
          },
          childCount: gridItems.length,
        ),
      );
    }

    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            if (previewItems.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: _gridSliver(previewItems, 0),
              ),
            if (showDivider)
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                sliver: SliverToBoxAdapter(child: _MomentsPremiumDividerBanner()),
              ),
            if (restItems.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: _gridSliver(
                  restItems,
                  showDivider ? widget.previewEndIndex : 0,
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.only(bottom: fabClearance + ctaClearance),
            ),
          ],
        ),
        if (showFloatingCta)
          Positioned(
            left: 24,
            right: 24,
            bottom: fabClearance + 8,
            child: Center(
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(28),
                child: InkWell(
                  onTap: () => showMomentsPremiumSheet(
                    context,
                    ref,
                    source: 'floating_cta',
                  ),
                  borderRadius: BorderRadius.circular(28),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: MomentsPremiumPageTokens.ctaGradient,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('✨', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 8),
                        Text(
                          'Unlock Moments',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.lock_open, color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MomentsPremiumDividerBanner extends StatelessWidget {
  const _MomentsPremiumDividerBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MomentsPremiumPageTokens.accentPurple.withValues(alpha: 0.4),
        ),
      ),
      child: const Text(
        'Unlock all moments with Premium',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
