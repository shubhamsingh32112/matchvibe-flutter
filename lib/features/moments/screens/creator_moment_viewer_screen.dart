import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/user_message_mapper.dart';
import '../../../shared/models/creator_model.dart';
import '../../../shared/providers/coin_purchase_popup_provider.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/services/chat_service.dart';
import '../../creator/providers/creator_dashboard_provider.dart';
import '../../home/providers/home_provider.dart';
import '../../home/utils/creator_location_display.dart';
import '../../home/widgets/creator_profile_screen.dart';
import '../../video/controllers/call_connection_controller.dart';
import '../../video/utils/call_admission_constants.dart';
import '../models/moments_models.dart';
import '../providers/moments_providers.dart';
import '../services/moments_api_service.dart';
import '../services/moment_share_service.dart';
import '../utils/moment_owner_actions.dart';
import '../utils/moments_follow_sync.dart';
import '../widgets/moment_card.dart';
import '../widgets/moment_comments_sheet.dart';
import '../widgets/moment_viewer_chrome.dart';

class CreatorMomentViewerScreen extends ConsumerStatefulWidget {
  const CreatorMomentViewerScreen({
    super.key,
    required this.items,
    required this.initialIndex,
    this.allowOwnerDelete = false,
    this.creatorId,
    this.initialMediaFilter = MomentsMediaFilter.all,
  });

  final List<MomentFeedItem> items;
  final int initialIndex;
  final bool allowOwnerDelete;
  final String? creatorId;
  final MomentsMediaFilter initialMediaFilter;

  @override
  ConsumerState<CreatorMomentViewerScreen> createState() =>
      _CreatorMomentViewerScreenState();
}

class _CreatorMomentViewerScreenState
    extends ConsumerState<CreatorMomentViewerScreen> {
  late final PageController _controller;
  late List<MomentFeedItem> _allItems;
  late MomentsMediaFilter _mediaFilter;
  late int _currentIndex;
  bool _isVideoMuted = true;
  bool _isInitiatingCall = false;
  bool _isOpeningChat = false;
  bool _isLikeBusy = false;
  bool _isShareBusy = false;
  final _momentsApi = MomentsApiService();
  final _shareService = MomentShareService();

  List<MomentFeedItem> get _visibleItems =>
      applyMediaFilter(_allItems, _mediaFilter);

  MomentFeedItem? get _currentItem {
    final items = _visibleItems;
    if (items.isEmpty || _currentIndex >= items.length) return null;
    return items[_currentIndex];
  }

  @override
  void initState() {
    super.initState();
    _allItems = List.of(widget.items);
    _mediaFilter = widget.initialMediaFilter;
    final visible = _visibleItems;
    final startItem = widget.items[
        widget.initialIndex.clamp(0, widget.items.length - 1)];
    final visibleStart = visible.indexWhere((item) => item.id == startItem.id);
    _currentIndex = visibleStart >= 0 ? visibleStart : 0;
    _controller = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordViewForCurrentItem();
      _mergeFollowStateFromProvider();
    });
  }

  Future<void> _mergeFollowStateFromProvider() async {
    if (!mounted) return;
    try {
      final followingIds = await ref.read(followingCreatorsProvider.future);
      if (!mounted) return;
      setState(() {
        _allItems = _allItems
            .map(
              (item) {
                final isFollowing = followingIds.contains(item.creatorId);
                return item.isFollowing == isFollowing
                    ? item
                    : item.copyWith(isFollowing: isFollowing);
              },
            )
            .toList();
      });
    } catch (_) {
      // Best-effort; feed items may already include isFollowing.
    }
  }

  String? _ownCreatorId() {
    return ref.read(creatorDashboardProvider).valueOrNull?.creatorProfile.id;
  }

  bool _isViewingOwnMoment(MomentFeedItem item) {
    if (widget.allowOwnerDelete) return true;
    final ownId = _ownCreatorId();
    return ownId != null && ownId == item.creatorId;
  }

  Future<void> _recordViewForCurrentItem() async {
    final item = _currentItem;
    if (item == null || _isViewingOwnMoment(item)) return;
    try {
      await _momentsApi.recordMomentView(item.id);
    } catch (_) {
      // Non-blocking; view counts are best-effort.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onFilterChanged(MomentsMediaFilter filter) {
    if (filter == _mediaFilter) return;
    final current = _currentItem;
    setState(() {
      _mediaFilter = filter;
      if (current != null) {
        final nextVisible = applyMediaFilter(_allItems, filter);
        final nextIndex = nextVisible.indexWhere((item) => item.id == current.id);
        _currentIndex = nextIndex >= 0 ? nextIndex : 0;
      } else {
        _currentIndex = 0;
      }
    });
    if (_controller.hasClients) {
      _controller.jumpToPage(_currentIndex);
    }
  }

  Future<void> _deleteCurrent() async {
    final item = _currentItem;
    if (item == null) return;
    final deleted = await deleteMomentWithRefresh(
      ref,
      context,
      item.id,
      creatorId: widget.creatorId ?? item.creatorId,
    );
    if (!deleted || !mounted) return;

    setState(() {
      _allItems.removeWhere((m) => m.id == item.id);
      final visible = _visibleItems;
      if (visible.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      if (_currentIndex >= visible.length) {
        _currentIndex = visible.length - 1;
      }
    });
  }

  String? _normalizedFirebaseUid(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _openCreatorChat(CreatorModel creator) async {
    if (_isOpeningChat) return;

    setState(() => _isOpeningChat = true);
    try {
      final chatService = ChatService();
      final result = await chatService.createOrGetChannel(creator.userId);
      final channelId = result['channelId'] as String?;

      if (channelId != null && mounted) {
        context.push('/chat/$channelId');
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          UserMessageMapper.userMessageFor(
            e,
            fallback: 'Couldn\'t open chat. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningChat = false);
    }
  }

  Future<void> _initiateVideoCall(CreatorModel creator) async {
    if (_isInitiatingCall) return;

    final creatorFirebaseUid = _normalizedFirebaseUid(creator.firebaseUid);
    if (creatorFirebaseUid == null) {
      if (mounted) {
        AppToast.showError(context, 'Creator information not available');
      }
      return;
    }

    final user = ref.read(authProvider).user;
    if (user != null && user.spendableCallCoins < kMinCoinsToCall) {
      if (mounted) {
        ref.read(coinPurchasePopupProvider.notifier).state = CoinPopupIntent(
          reason: 'preflight_low_coins_moment_viewer',
          dedupeKey: 'low-coins-moment-${creator.id}',
          remoteDisplayName: creator.name,
          remotePhotoUrl: creator.feedTileUrl,
          remoteFirebaseUid: creatorFirebaseUid,
        );
      }
      return;
    }

    setState(() => _isInitiatingCall = true);
    try {
      await ref.read(callConnectionControllerProvider.notifier).startUserCall(
            creatorFirebaseUid: creatorFirebaseUid,
            creatorMongoId: creator.id,
            creatorImageUrl: creator.feedTileUrl,
            creatorName: creator.name,
            creatorAge: creatorDisplayAge(creator),
            creatorCountry: creatorDisplayCountry(creator),
          );
    } finally {
      if (mounted) setState(() => _isInitiatingCall = false);
    }
  }

  void _onFollowChanged(String creatorId, bool isFollowing) {
    setState(() {
      _allItems = _allItems
          .map(
            (item) => item.creatorId == creatorId
                ? item.copyWith(isFollowing: isFollowing)
                : item,
          )
          .toList();
    });
    syncFollowState(
      ref,
      creatorId: creatorId,
      isFollowing: isFollowing,
    );
  }

  void _updateCurrentItem(MomentFeedItem updated) {
    setState(() {
      final allIndex = _allItems.indexWhere((m) => m.id == updated.id);
      if (allIndex >= 0) {
        _allItems[allIndex] = updated;
      }
    });
  }

  Future<void> _toggleLike(MomentFeedItem item) async {
    if (_isLikeBusy || item.locked) return;
    final optimistic = item.copyWith(
      isLiked: !item.isLiked,
      likesCount: item.isLiked
          ? (item.likesCount > 0 ? item.likesCount - 1 : 0)
          : item.likesCount + 1,
    );
    _updateCurrentItem(optimistic);
    setState(() => _isLikeBusy = true);
    try {
      final result = item.isLiked
          ? await _momentsApi.unlikeMoment(item.id)
          : await _momentsApi.likeMoment(item.id);
      if (!mounted) return;
      _updateCurrentItem(
        optimistic.copyWith(
          isLiked: result.isLiked,
          likesCount: result.likesCount,
        ),
      );
    } catch (_) {
      if (mounted) {
        _updateCurrentItem(item);
        AppToast.showError(context, 'Could not update like. Try again.');
      }
    } finally {
      if (mounted) setState(() => _isLikeBusy = false);
    }
  }

  void _doubleTapLike(MomentFeedItem item) {
    if (_isLikeBusy || item.locked || item.isLiked) return;
    unawaited(_toggleLike(item));
  }

  Future<void> _openComments(MomentFeedItem item) async {
    if (item.locked) return;
    final momentId = item.id;
    await showMomentCommentsSheet(
      context: context,
      momentId: momentId,
      initialCommentsCount: item.commentsCount,
      onCommentsCountChanged: (count) {
        final idx = _allItems.indexWhere((m) => m.id == momentId);
        if (idx >= 0) {
          _updateCurrentItem(_allItems[idx].copyWith(commentsCount: count));
        }
      },
    );
  }

  Future<void> _shareMoment(MomentFeedItem item) async {
    if (_isShareBusy) return;
    setState(() => _isShareBusy = true);
    try {
      await _shareService.shareMoment(item.id);
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, 'Could not share this moment');
      }
    } finally {
      if (mounted) setState(() => _isShareBusy = false);
    }
  }

  void _showMoreMenu() {
    final item = _currentItem;
    if (item == null) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline, color: Colors.white),
                title: const Text(
                  'View creator profile',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  openCreatorProfile(context, ref, item.creatorId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.white),
                title: const Text(
                  'Report',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report submitted. Thank you.'),
                    ),
                  );
                },
              ),
              if (widget.allowOwnerDelete)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.white),
                  title: const Text(
                    'Delete post',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(_deleteCurrent());
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CallConnectionState>(callConnectionControllerProvider, (
      prev,
      next,
    ) {
      if (_isInitiatingCall &&
          next.phase == CallConnectionPhase.failed &&
          next.error != null &&
          mounted) {
        AppToast.showError(context, next.error!);
      }
    });

    final visibleItems = _visibleItems;
    if (visibleItems.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: buildMomentViewerAppBar(
          context,
          mediaFilter: _mediaFilter,
          onFilterChanged: _onFilterChanged,
          itemCount: 0,
          currentIndex: 0,
        ),
        body: const Center(
          child: Text(
            'No moments match this filter',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final currentItem = _currentItem!;
    final viewingOwnMoment = _isViewingOwnMoment(currentItem);
    final showContactActions = !viewingOwnMoment;
    final myMoments = ref.watch(myMomentsProvider).valueOrNull;
    final ownerViewCount = viewingOwnMoment
        ? myMoments
                ?.where((m) => m.id == currentItem.id)
                .map((m) => m.viewsCount)
                .firstOrNull ??
            currentItem.viewsCount ??
            0
        : null;

    final creatorAsync = showContactActions
        ? ref.watch(creatorDetailProvider(currentItem.creatorId))
        : null;

    Widget? contactBar;
    if (showContactActions && creatorAsync != null) {
      contactBar = creatorAsync.when(
        data: (creator) => MomentViewerBottomBar(
          creatorId: currentItem.creatorId,
          creatorName: creator.name,
          countryFlag: creatorLocationFlagEmoji(creator.location),
          isFollowing: currentItem.isFollowing,
          isOpeningChat: _isOpeningChat,
          isCalling: _isInitiatingCall,
          onCreatorTap: () =>
              openCreatorProfile(context, ref, currentItem.creatorId),
          onChatPressed: _isOpeningChat
              ? null
              : () => unawaited(_openCreatorChat(creator)),
          onVideoCallPressed: _isInitiatingCall
              ? null
              : () => unawaited(_initiateVideoCall(creator)),
        ),
        loading: () => MomentViewerBottomBar(
          creatorId: currentItem.creatorId,
          creatorName: currentItem.creatorName,
          countryFlag: creatorLocationFlagEmoji(null),
          isFollowing: currentItem.isFollowing,
          isOpeningChat: _isOpeningChat,
          isCalling: _isInitiatingCall,
          onCreatorTap: () =>
              openCreatorProfile(context, ref, currentItem.creatorId),
          onChatPressed: null,
          onVideoCallPressed: null,
        ),
        error: (_, __) => MomentViewerBottomBar(
          creatorId: currentItem.creatorId,
          creatorName: currentItem.creatorName,
          countryFlag: creatorLocationFlagEmoji(null),
          isFollowing: currentItem.isFollowing,
          isOpeningChat: _isOpeningChat,
          isCalling: _isInitiatingCall,
          onCreatorTap: () =>
              openCreatorProfile(context, ref, currentItem.creatorId),
          onChatPressed: null,
          onVideoCallPressed: null,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: buildMomentViewerAppBar(
        context,
        mediaFilter: _mediaFilter,
        onFilterChanged: _onFilterChanged,
        itemCount: visibleItems.length,
        currentIndex: _currentIndex,
        onMorePressed: _showMoreMenu,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            scrollDirection: Axis.vertical,
            allowImplicitScrolling: false,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              _recordViewForCurrentItem();
            },
            itemCount: visibleItems.length,
            itemBuilder: (context, index) {
              final item = visibleItems[index];
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
                viewerLayout: true,
                playbackContext: 'profile',
                playerInitDelay: initDelay,
                isVideoMuted: _isVideoMuted,
                bottomOverlayInset: showContactActions ? 200 : 120,
                showEngagementRail: true,
                engagementEnabled: !item.locked,
                showFollowOnRail: !viewingOwnMoment && !item.isFollowing,
                isLikeBusy: _isLikeBusy && item.id == _currentItem?.id,
                isShareBusy: _isShareBusy && item.id == _currentItem?.id,
                onLike: () => unawaited(_toggleLike(item)),
                onDoubleTapLike: () => _doubleTapLike(item),
                onComment: () => unawaited(_openComments(item)),
                onShare: () => unawaited(_shareMoment(item)),
                onFollowChanged: (isFollowing, _) =>
                    _onFollowChanged(item.creatorId, isFollowing),
                onMuteToggle: () =>
                    setState(() => _isVideoMuted = !_isVideoMuted),
                onItemUpdated: _updateCurrentItem,
                onCreatorTap: () =>
                    openCreatorProfile(context, ref, item.creatorId),
                onReport: _showMoreMenu,
              );
            },
          ),
          if (viewingOwnMoment && ownerViewCount != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 56,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.visibility_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Unique views: $ownerViewCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (contactBar != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(top: false, child: contactBar),
            ),
        ],
      ),
    );
  }
}
