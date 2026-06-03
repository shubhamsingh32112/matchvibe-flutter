import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/images/image_cache_managers.dart';
import '../../../core/services/meta_app_events_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../video/utils/call_admission_constants.dart';
import '../../../shared/models/creator_model.dart';
import '../../../shared/providers/coin_purchase_popup_provider.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../../../shared/widgets/creator_price_per_minute_label.dart';
import '../../../shared/widgets/paged_gallery_image_viewer.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/services/chat_service.dart';
import '../../moments/providers/moments_providers.dart';
import '../../moments/screens/creator_moment_viewer_screen.dart';
import '../../moments/widgets/follow_creator_button.dart';
import '../../video/controllers/call_connection_controller.dart';
import '../providers/availability_provider.dart';
import '../providers/home_provider.dart';
import 'call_button_variant.dart';

void openCreatorProfile(
  BuildContext context,
  WidgetRef ref,
  String creatorId,
) {
  unawaited(
    MetaAppEventsService.logViewContent(
      contentId: creatorId,
      contentType: 'creator_profile',
    ),
  );
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CreatorProfileScreen(creatorId: creatorId),
    ),
  );
}

int creatorDisplayAge(CreatorModel creator) {
  if (creator.age != null) return creator.age!;
  final source = '${creator.name} ${creator.about}';
  final match = RegExp(r'\b(1[89]|[2-9]\d)\b').firstMatch(source);
  if (match == null) return 24;
  return int.tryParse(match.group(0) ?? '') ?? 24;
}

String creatorDisplayCountry(CreatorModel creator) {
  return 'India';
}

class CreatorProfileScreen extends ConsumerStatefulWidget {
  const CreatorProfileScreen({
    super.key,
    required this.creatorId,
    this.initialCreator,
    this.onCallPressed,
    this.onChatPressed,
    this.isCalling = false,
    this.isOpeningChat = false,
  });

  final String creatorId;
  final CreatorModel? initialCreator;
  final VoidCallback? onCallPressed;
  final VoidCallback? onChatPressed;
  final bool isCalling;
  final bool isOpeningChat;

  @override
  ConsumerState<CreatorProfileScreen> createState() =>
      _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends ConsumerState<CreatorProfileScreen> {
  int _mediaTabIndex = 0;
  bool _isInitiatingCall = false;
  bool _isOpeningChat = false;

  String? _normalizedFirebaseUid(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
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
          reason: 'preflight_low_coins_profile',
          dedupeKey: 'low-coins-profile-${creator.id}',
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

  static List<({
    String thumbUrl,
    String fullUrl,
    String? blurhash,
    String? heroTag,
  })> _galleryItems(CreatorModel c) {
    final sorted = List<CreatorGalleryImage>.from(c.galleryImages)
      ..sort((a, b) => a.position.compareTo(b.position));
    final out = <({
      String thumbUrl,
      String fullUrl,
      String? blurhash,
      String? heroTag,
    })>[];
    for (final e in sorted) {
      final viewer = e.viewerUrl?.trim();
      if (viewer == null || viewer.isEmpty) continue;
      final thumb = e.previewUrl?.trim();
      out.add((
        thumbUrl: (thumb != null && thumb.isNotEmpty) ? thumb : viewer,
        fullUrl: viewer,
        blurhash: e.asset?.blurhash,
        heroTag: e.asset != null ? 'gallery-${e.asset!.imageId}' : null,
      ));
    }
    return out;
  }

  void _openGalleryViewer(
    BuildContext context,
    List<({
      String thumbUrl,
      String fullUrl,
      String? blurhash,
      String? heroTag,
    })> items, {
    required int initialIndex,
  }) {
    if (items.isEmpty) return;
    final viewerItems = [
      for (final item in items)
        GalleryViewerItem(
          imageUrl: item.fullUrl,
          blurhash: item.blurhash,
          heroTag: item.heroTag,
        ),
    ];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => PagedGalleryImageViewer(
          items: viewerItems,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  CreatorAvailability _resolveAvailability(CreatorModel creator) {
    final firebaseUid = _normalizedFirebaseUid(creator.firebaseUid);
    if (firebaseUid == null || firebaseUid.isEmpty) {
      return creator.availability == 'online'
          ? CreatorAvailability.online
          : creator.availability == 'on_call'
          ? CreatorAvailability.onCall
          : CreatorAvailability.offline;
    }
    final hasHydrated = ref.watch(
      creatorAvailabilityProvider.select((map) => map.containsKey(firebaseUid)),
    );
    if (hasHydrated) {
      return ref.watch(creatorStatusProvider(firebaseUid));
    }
    return creator.availability == 'online'
        ? CreatorAvailability.online
        : creator.availability == 'on_call'
        ? CreatorAvailability.onCall
        : CreatorAvailability.offline;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detailAsync = ref.watch(creatorDetailProvider(widget.creatorId));
    final merged = detailAsync.maybeWhen(
      data: (d) => widget.initialCreator?.copyWith(
            about: d.about,
            galleryImages: d.galleryImages,
            avatar: d.avatar,
          ) ??
          d,
      orElse: () => widget.initialCreator,
    );

    if (merged == null) {
      return Scaffold(
        appBar: buildBrandAppBar(context, title: 'Profile'),
        backgroundColor: AppBrandGradients.accountMenuPageBackground,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final availability = _resolveAvailability(merged);
    final galleryItems = _galleryItems(merged);
    final galleryLoading =
        detailAsync.isLoading && merged.galleryImages.isEmpty;
    final summaryAsync = ref.watch(creatorSummaryProvider(merged.id));
    final momentsAsync = ref.watch(creatorMomentsProvider(merged.id));

    final userRole = ref.watch(authProvider.select((s) => s.user?.role));
    final welcomeFreeCallEligible = ref.watch(
      authProvider.select((s) => s.user?.welcomeFreeCallEligible == true),
    );
    final isRegularUser = userRole == 'user';
    final callVariant = welcomeFreeCallEligible
        ? CallButtonVariant.welcomeFree
        : CallButtonVariant.normal;

    final isCalling = widget.isCalling || _isInitiatingCall;
    final isOpeningChat = widget.isOpeningChat || _isOpeningChat;

    void onChat() {
      if (widget.onChatPressed != null) {
        widget.onChatPressed!();
      } else {
        unawaited(_openCreatorChat(merged));
      }
    }

    void onCall() {
      if (widget.onCallPressed != null) {
        widget.onCallPressed!();
      } else {
        unawaited(_initiateVideoCall(merged));
      }
    }

    return Scaffold(
      appBar: buildBrandAppBar(context, title: merged.name),
      body: ColoredBox(
        color: AppBrandGradients.accountMenuPageBackground,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: AppAvatar(
                        avatarAsset: merged.avatar,
                        size: 100,
                        heroTag: 'creator-avatar-${merged.id}',
                        fallbackText:
                            merged.name.isNotEmpty ? merged.name[0] : 'C',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: Text(
                        availability == CreatorAvailability.online
                            ? '● Online'
                            : availability == CreatorAvailability.onCall
                            ? '● On call'
                            : '● Offline',
                        style: TextStyle(
                          color: availability == CreatorAvailability.online
                              ? AppPalette.success
                              : availability == CreatorAvailability.onCall
                              ? AppPalette.warning
                              : AppPalette.subtitle,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: Text(
                        '${merged.name} ${creatorDisplayAge(merged)}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Center(
                      child: Text(
                        creatorDisplayCountry(merged),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: CreatorPricePerMinuteLabel(
                        price: merged.price,
                        iconColor: scheme.onSurface,
                        textStyle: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    summaryAsync.when(
                      data: (summary) => Center(
                        child: Text(
                          '${summary.followerCount} followers · '
                          '${summary.followingCount} following · '
                          '${summary.postCount} posts',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      loading: () => const SizedBox(height: 4),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: FollowCreatorButton(
                        creatorId: merged.id,
                        initiallyFollowing:
                            summaryAsync.valueOrNull?.isFollowing,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'About Me',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (detailAsync.isLoading && merged.about.trim().isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        merged.about.trim().isNotEmpty
                            ? merged.about
                            : 'No bio available.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: BrandFeedTabChip(
                            label: 'Posts',
                            selected: _mediaTabIndex == 0,
                            onTap: () => setState(() => _mediaTabIndex = 0),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: BrandFeedTabChip(
                            label: 'Pictures',
                            selected: _mediaTabIndex == 1,
                            onTap: () => setState(() => _mediaTabIndex = 1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_mediaTabIndex == 0)
                      momentsAsync.when(
                        data: (posts) {
                          if (posts.isEmpty) {
                            return Text(
                              'No posts yet',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            );
                          }
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: AppSpacing.sm,
                                  mainAxisSpacing: AppSpacing.sm,
                                  childAspectRatio: 0.85,
                                ),
                            itemCount: posts.length,
                            itemBuilder: (context, index) {
                              final post = posts[index];
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            CreatorMomentViewerScreen(
                                              items: posts,
                                              initialIndex: index,
                                            ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      AppNetworkImage(
                                        imageUrl: post.media.thumbnailUrl,
                                        width: 140,
                                        height: 180,
                                        fit: BoxFit.cover,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      if (post.locked)
                                        const Positioned(
                                          top: 6,
                                          right: 6,
                                          child: Icon(
                                            Icons.lock,
                                            color: Colors.white,
                                            shadows: [
                                              Shadow(color: Colors.black54),
                                            ],
                                          ),
                                        ),
                                      if (post.media.isVideo)
                                        const Positioned(
                                          bottom: 6,
                                          left: 6,
                                          child: Icon(
                                            Icons.play_circle_fill,
                                            color: Colors.white,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.lg),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: (e, _) => Text('Failed to load posts: $e'),
                      )
                    else if (galleryLoading)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: AppSpacing.sm,
                              mainAxisSpacing: AppSpacing.sm,
                              childAspectRatio: 0.85,
                            ),
                        itemCount: 6,
                        itemBuilder: (_, __) => DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      )
                    else if (galleryItems.isEmpty)
                      Text(
                        'no pictures added',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: AppSpacing.sm,
                              mainAxisSpacing: AppSpacing.sm,
                              childAspectRatio: 0.85,
                            ),
                        itemCount: galleryItems.length,
                        itemBuilder: (context, index) {
                          final item = galleryItems[index];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _openGalleryViewer(
                                context,
                                galleryItems,
                                initialIndex: index,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              child: AppNetworkImage(
                                imageUrl: item.thumbUrl,
                                width: 140,
                                height: 180,
                                fit: BoxFit.cover,
                                borderRadius: BorderRadius.circular(14),
                                cacheManager: galleryCacheManager,
                                blurhash: item.blurhash,
                                heroTag: item.heroTag,
                                variantTag: 'galleryThumb',
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            if (isRegularUser)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isOpeningChat ? null : onChat,
                          icon: isOpeningChat
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.chat_bubble_outline),
                          label: const Text('Chat'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: availability == CreatorAvailability.online
                              ? (isCalling ? null : onCall)
                              : null,
                          icon: isCalling
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  callVariant.showWelcomePromo
                                      ? Icons.phone
                                      : Icons.videocam,
                                ),
                          label: Text(
                            callVariant.showWelcomePromo
                                ? 'Free intro call'
                                : 'Video Call',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: callVariant.showWelcomePromo
                                ? AppPalette.success
                                : AppBrandGradients.userHomeVideoCall,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
