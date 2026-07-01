import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../providers/moments_providers.dart';

/// App bar matching the homepage / Moments tab purple gradient header.
PreferredSizeWidget buildMomentViewerAppBar(
  BuildContext context, {
  required MomentsMediaFilter mediaFilter,
  required ValueChanged<MomentsMediaFilter> onFilterChanged,
  required int itemCount,
  required int currentIndex,
  VoidCallback? onMorePressed,
}) {
  String filterLabel(MomentsMediaFilter filter) {
    switch (filter) {
      case MomentsMediaFilter.all:
        return 'All Moments';
      case MomentsMediaFilter.photos:
        return 'Photos';
      case MomentsMediaFilter.videos:
        return 'Videos';
    }
  }

  final progressHeight = itemCount > 1 ? 20.0 : 8.0;

  return buildBrandAppBar(
    context,
    title: 'Moments ✨',
    centerTitle: true,
    automaticallyImplyLeading: false,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => Navigator.of(context).pop(),
    ),
    actions: [
      PopupMenuButton<MomentsMediaFilter>(
        initialValue: mediaFilter,
        tooltip: 'Filter moments',
        color: const Color(0xFF1E1E1E),
        onSelected: onFilterChanged,
        offset: const Offset(0, 40),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                filterLabel(mediaFilter),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: MomentsMediaFilter.all,
            child: Text('All Moments'),
          ),
          PopupMenuItem(
            value: MomentsMediaFilter.photos,
            child: Text('Photos'),
          ),
          PopupMenuItem(
            value: MomentsMediaFilter.videos,
            child: Text('Videos'),
          ),
        ],
      ),
      IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: onMorePressed,
      ),
    ],
    bottom: PreferredSize(
      preferredSize: Size.fromHeight(progressHeight),
      child: MomentViewerProgressBar(
        itemCount: itemCount,
        currentIndex: currentIndex,
      ),
    ),
  );
}

class MomentViewerProgressBar extends StatelessWidget {
  const MomentViewerProgressBar({
    super.key,
    required this.itemCount,
    required this.currentIndex,
  });

  final int itemCount;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 1) return const SizedBox(height: 8);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: List.generate(itemCount, (index) {
          final isActive = index == currentIndex;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == itemCount - 1 ? 0 : 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 3,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppBrandGradients.momentsTabActiveColor
                      : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class MomentViewerActionButton extends StatelessWidget {
  const MomentViewerActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final canTap = !isLoading && onPressed != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canTap ? onPressed : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppBrandGradients.momentsViewerActionGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MomentViewerBottomBar extends ConsumerWidget {
  const MomentViewerBottomBar({
    super.key,
    required this.creatorId,
    required this.creatorName,
    required this.countryFlag,
    required this.onChatPressed,
    required this.onVideoCallPressed,
    this.isFollowing,
    this.isOpeningChat = false,
    this.isCalling = false,
    this.onFollowChanged,
    this.onCreatorTap,
  });

  final String creatorId;
  final String creatorName;
  final String countryFlag;
  final VoidCallback? onChatPressed;
  final VoidCallback? onVideoCallPressed;
  final bool? isFollowing;
  final bool isOpeningChat;
  final bool isCalling;
  final void Function(bool isFollowing, int followerCount)? onFollowChanged;
  final VoidCallback? onCreatorTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onCreatorTap,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    '$creatorName $countryFlag',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified,
                size: 16,
                color: AppBrandGradients.creatorProfileInactiveTabColor,
              ),
              const SizedBox(width: 4),
              Text(
                'Verified Creator',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MomentViewerActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chat',
                  isLoading: isOpeningChat,
                  onPressed: onChatPressed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MomentViewerActionButton(
                  icon: Icons.videocam_outlined,
                  label: 'Video Call',
                  isLoading: isCalling,
                  onPressed: onVideoCallPressed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MomentViewerPremiumBadge extends StatelessWidget {
  const MomentViewerPremiumBadge({
    super.key,
    required this.unlockLabel,
    required this.onTap,
    this.isLoading = false,
  });

  final String unlockLabel;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock,
                  size: 14,
                  color: AppBrandGradients.momentsTabActiveColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'Premium',
                  style: TextStyle(
                    color: AppBrandGradients.momentsTabActiveColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Text(
                    unlockLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
