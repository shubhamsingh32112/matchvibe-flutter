import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/images/image_cache_managers.dart';
import '../../../core/services/meta_app_events_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/compact_count_formatter.dart';
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
import '../../../shared/widgets/gem_icon.dart';
import '../../../shared/widgets/paged_gallery_image_viewer.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/services/chat_service.dart';
import '../../moments/models/moments_models.dart';
import '../../moments/providers/moments_providers.dart';
import '../../creator/constants/creator_home_assets.dart';
import '../../creator/providers/creator_dashboard_provider.dart';
import '../constants/creator_profile_assets.dart';
import '../../moments/screens/creator_moment_viewer_screen.dart';
import '../../moments/utils/moment_owner_actions.dart';
import '../../moments/widgets/follow_creator_button.dart';
import '../../video/controllers/call_connection_controller.dart';
import '../../../core/config/app_config_provider.dart';
import '../../vip/widgets/schedule_call_sheet.dart';
import '../../vip/widgets/vip_upsell_dialog.dart';
import '../../video/providers/call_billing_provider.dart';
import '../providers/availability_provider.dart';
import '../providers/home_provider.dart';
import '../utils/creator_location_display.dart';
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
  /// 0 = Photos (gallery), 1 = Moments (uploaded posts/reels).
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

  int _resolveUserCoins() {
    final authCoins = ref.watch(
      authProvider.select((s) => s.user?.coins ?? 0),
    );
    final billingSlice = ref.watch(
      callBillingProvider.select((b) => (b.runtimeState, b.userCoins)),
    );
    final useLiveCoins =
        billingSlice.$1 == BillingRuntimeState.active ||
        billingSlice.$1 == BillingRuntimeState.recovering;
    return useLiveCoins ? billingSlice.$2 : authCoins;
  }

  PreferredSizeWidget _buildAppBar(bool isRegularUser) {
    final actions = <Widget>[];
    if (isRegularUser) {
      actions.addAll([
        IconButton(
          tooltip: 'Favorite creators',
          icon: const Icon(Icons.favorite_border),
          onPressed: () => context.push('/home/favorites'),
        ),
        BrandHeaderCoinsChip(coins: _resolveUserCoins()),
      ]);
    }
    return buildBrandAppBar(
      context,
      title: AppConstants.appName,
      actions: actions,
    );
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
            location: d.location,
          ) ??
          d,
      orElse: () => widget.initialCreator,
    );

    if (merged == null) {
      return Scaffold(
        appBar: buildBrandAppBar(context, title: AppConstants.appName),
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
    final ownCreatorId = ref.watch(
      creatorDashboardProvider.select((a) => a.valueOrNull?.creatorProfile.id),
    );
    final isOwnProfile = ownCreatorId != null && ownCreatorId == merged.id;

    final userRole = ref.watch(authProvider.select((s) => s.user?.role));
    final welcomeFreeCallEligible = ref.watch(
      authProvider.select((s) => s.user?.welcomeFreeCallEligible == true),
    );
    final isRegularUser = userRole == 'user';
    final isVip = ref.watch(authProvider.select((s) => s.user?.isVipActive == true));
    final vipEnabled = ref.watch(appFeaturesProvider).vipEnabled;
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
      appBar: _buildAppBar(isRegularUser),
      body: ColoredBox(
        color: AppBrandGradients.accountMenuPageBackground,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CreatorProfileAvatar(
                creator: merged,
                availability: availability,
              ),
              const SizedBox(height: AppSpacing.sm),
              _CreatorProfileIdentity(creator: merged),
              if (isRegularUser) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _CreatorProfileVideoCallButton(
                        price: merged.price,
                        callVariant: callVariant,
                        isCalling: isCalling,
                        enabled: availability == CreatorAvailability.online,
                        onPressed: onCall,
                      ),
                    ),
                    if (vipEnabled) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 2,
                        child: _CreatorProfileScheduleCallButton(
                          isHostOnline:
                              availability == CreatorAvailability.online,
                          onPressed: () {
                            if (isVip) {
                              showScheduleCallSheet(
                                context: context,
                                ref: ref,
                                creatorId: merged.id,
                                creatorName: merged.name,
                              );
                            } else {
                              showVipExclusiveFeatureDialog(context);
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _CreatorProfileSecondaryButton(
                        iconAsset: CreatorProfileAssets.chatIcon,
                        icon: Icons.chat_bubble_outline,
                        label: 'Chat',
                        isLoading: isOpeningChat,
                        onPressed: isOpeningChat ? null : onChat,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FollowCreatorButton(
                        creatorId: merged.id,
                        initiallyFollowing:
                            summaryAsync.valueOrNull?.isFollowing,
                        style: CreatorFollowButtonStyle.profileCard,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _CreatorProfileStatsCard(summaryAsync: summaryAsync),
              const SizedBox(height: AppSpacing.lg),
              _CreatorProfileMediaTabBar(
                selectedIndex: _mediaTabIndex,
                onPhotosTap: () => setState(() => _mediaTabIndex = 0),
                onMomentsTap: () => setState(() => _mediaTabIndex = 1),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_mediaTabIndex == 0)
                _buildPhotosTab(
                  context,
                  scheme,
                  galleryItems,
                  galleryLoading,
                )
              else
                _buildMomentsTab(
                  context,
                  scheme,
                  momentsAsync,
                  isOwnProfile: isOwnProfile,
                  creatorId: merged.id,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotosTab(
    BuildContext context,
    ColorScheme scheme,
    List<({
      String thumbUrl,
      String fullUrl,
      String? blurhash,
      String? heroTag,
    })> galleryItems,
    bool galleryLoading,
  ) {
    if (galleryLoading) {
      return _buildGallerySkeleton(scheme);
    }
    if (galleryItems.isEmpty) {
      return Text(
        'No photos yet',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
    );
  }

  Widget _buildGallerySkeleton(ColorScheme scheme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.85,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => DecoratedBox(
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
    );
  }

  Widget _buildMomentsTab(
    BuildContext context,
    ColorScheme scheme,
    AsyncValue<List<MomentFeedItem>> momentsAsync, {
    required bool isOwnProfile,
    required String creatorId,
  }) {
    return momentsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return Text(
            'No moments yet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                      builder: (_) => CreatorMomentViewerScreen(
                        items: posts,
                        initialIndex: index,
                        allowOwnerDelete: isOwnProfile,
                        creatorId: creatorId,
                      ),
                    ),
                  );
                },
                onLongPress: isOwnProfile
                    ? () => deleteMomentWithRefresh(
                          ref,
                          context,
                          post.id,
                          creatorId: creatorId,
                        )
                    : null,
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
                          shadows: [Shadow(color: Colors.black54)],
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
                    if (isOwnProfile)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Material(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => deleteMomentWithRefresh(
                              ref,
                              context,
                              post.id,
                              creatorId: creatorId,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(3),
                              child: Icon(
                                Icons.delete_outline,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
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
      error: (e, _) => Text('Failed to load moments: $e'),
    );
  }
}

class _CreatorProfileAvatar extends StatelessWidget {
  const _CreatorProfileAvatar({
    required this.creator,
    required this.availability,
  });

  final CreatorModel creator;
  final CreatorAvailability availability;

  Color get _dotColor {
    switch (availability) {
      case CreatorAvailability.online:
        return const Color(0xFF4CAF50);
      case CreatorAvailability.onCall:
        return const Color(0xFFFFB74D);
      case CreatorAvailability.offline:
        return const Color(0xFFBDBDBD);
    }
  }

  @override
  Widget build(BuildContext context) {
    const avatarSize = 116.0;
    const dotSize = 16.0;

    return Center(
      child: SizedBox(
        width: avatarSize,
        height: avatarSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AppAvatar(
              avatarAsset: creator.avatar,
              size: avatarSize,
              heroTag: 'creator-avatar-${creator.id}',
              fallbackText: creator.name.isNotEmpty ? creator.name[0] : 'C',
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _dotColor,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatorProfileIdentity extends StatelessWidget {
  const _CreatorProfileIdentity({required this.creator});

  final CreatorModel creator;

  @override
  Widget build(BuildContext context) {
    final flag = creatorLocationFlagEmoji(creator.location);
    final age = creatorDisplayAge(creator);

    return Column(
      children: [
        Text(
          '${creator.name} $flag $age',
          textAlign: TextAlign.center,
          style: GoogleFonts.lexend(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified,
              size: 20,
              color: AppBrandGradients.creatorProfileInactiveTabColor,
            ),
            const SizedBox(width: 4),
            Text(
              'Verified Creator',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppBrandGradients.creatorProfileInactiveTabColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CreatorProfileScheduleCallButton extends StatelessWidget {
  const _CreatorProfileScheduleCallButton({
    required this.isHostOnline,
    required this.onPressed,
  });

  final bool isHostOnline;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppBrandGradients.creatorProfileVideoCallGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              if (!isHostOnline)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.38),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        CreatorProfileAssets.scheduleCallIcon,
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.event_available_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Schedule Call',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatorProfileVideoCallButton extends StatelessWidget {
  const _CreatorProfileVideoCallButton({
    required this.price,
    required this.callVariant,
    required this.isCalling,
    required this.enabled,
    required this.onPressed,
  });

  final double price;
  final CallButtonVariant callVariant;
  final bool isCalling;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final formattedPrice = formatCreatorPricePerMinute(price);
    final subtitle = callVariant.showWelcomePromo
        ? 'Free intro call'
        : formattedPrice.isNotEmpty
        ? formattedPrice
        : null;

    final gradient = callVariant.showWelcomePromo
        ? const LinearGradient(
            colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
          )
        : AppBrandGradients.creatorProfileVideoCallGradient;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled && !isCalling ? onPressed : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              if (!enabled)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.38),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isCalling)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      Icon(
                        callVariant.showWelcomePromo
                            ? Icons.phone
                            : Icons.videocam,
                        color: Colors.white,
                        size: 24,
                      ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          callVariant.showWelcomePromo
                              ? 'Free intro call'
                              : 'Video Call',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        if (subtitle != null &&
                            !callVariant.showWelcomePromo) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const GemIcon(size: 18),
                              const SizedBox(width: 4),
                              Text(
                                '$subtitle / min',
                                style: GoogleFonts.lexend(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatorProfileSecondaryButton extends StatelessWidget {
  const _CreatorProfileSecondaryButton({
    this.icon,
    this.iconAsset,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  }) : assert(icon != null || iconAsset != null);

  final IconData? icon;
  final String? iconAsset;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 0,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppBrandGradients.accountMenuCardShadow,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (iconAsset != null)
                Image.asset(
                  iconAsset!,
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => Icon(
                    icon ?? Icons.chat_bubble_outline,
                    color: AppBrandGradients.creatorProfileAccentPink,
                    size: 22,
                  ),
                )
              else
                Icon(
                  icon!,
                  color: AppBrandGradients.creatorProfileAccentPink,
                  size: 22,
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatorProfileStatsCard extends StatelessWidget {
  const _CreatorProfileStatsCard({required this.summaryAsync});

  final AsyncValue<CreatorSummary> summaryAsync;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppBrandGradients.accountMenuCardShadow,
      ),
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: summaryAsync.when(
                data: (summary) => _StatColumn(
                  icon: Icons.people_outline,
                  iconColor: AppBrandGradients.creatorProfileAccentPink,
                  value: formatCompactCount(summary.followerCount),
                  label: 'Followers',
                ),
                loading: () => const _StatColumnSkeleton(),
                error: (_, _) => const _StatColumn(
                  icon: Icons.people_outline,
                  iconColor: AppBrandGradients.creatorProfileAccentPink,
                  value: '—',
                  label: 'Followers',
                ),
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Colors.grey.shade200,
            ),
            Expanded(
              child: summaryAsync.when(
                data: (summary) => _StatColumn(
                  icon: Icons.play_circle_outline,
                  iconColor: AppBrandGradients.creatorProfileInactiveTabColor,
                  value: formatCompactCount(summary.postCount),
                  label: 'Moments',
                ),
                loading: () => const _StatColumnSkeleton(),
                error: (_, _) => const _StatColumn(
                  icon: Icons.play_circle_outline,
                  iconColor: AppBrandGradients.creatorProfileInactiveTabColor,
                  value: '—',
                  label: 'Moments',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 26),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppPalette.subtitle,
          ),
        ),
      ],
    );
  }
}

class _StatColumnSkeleton extends StatelessWidget {
  const _StatColumnSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 48,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 64,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _CreatorProfileMediaTabBar extends StatelessWidget {
  const _CreatorProfileMediaTabBar({
    required this.selectedIndex,
    required this.onPhotosTap,
    required this.onMomentsTap,
  });

  final int selectedIndex;
  final VoidCallback onPhotosTap;
  final VoidCallback onMomentsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MediaTab(
            label: 'Photos',
            iconAsset: CreatorHomeAssets.reelsTab,
            fallbackIcon: Icons.play_circle_outline,
            selected: selectedIndex == 0,
            activeColor: AppBrandGradients.creatorProfileActiveTabColor,
            inactiveColor: AppBrandGradients.creatorProfileInactiveTabColor,
            onTap: onPhotosTap,
          ),
        ),
        Expanded(
          child: _MediaTab(
            label: 'Moments',
            iconAsset: CreatorHomeAssets.reelsTab,
            fallbackIcon: Icons.play_circle_outline,
            selected: selectedIndex == 1,
            activeColor: AppBrandGradients.creatorProfileActiveTabColor,
            inactiveColor: AppBrandGradients.creatorProfileInactiveTabColor,
            onTap: onMomentsTap,
          ),
        ),
      ],
    );
  }
}

class _MediaTab extends StatelessWidget {
  const _MediaTab({
    required this.label,
    this.icon,
    this.iconAsset,
    this.fallbackIcon,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  }) : assert(icon != null || iconAsset != null);

  final String label;
  final IconData? icon;
  final String? iconAsset;
  final IconData? fallbackIcon;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  Widget _buildTabIcon(Color color) {
    if (iconAsset != null) {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        child: Image.asset(
          iconAsset!,
          width: 20,
          height: 20,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => Icon(
            fallbackIcon ?? icon ?? Icons.play_circle_outline,
            color: color,
            size: 20,
          ),
        ),
      );
    }
    return Icon(icon!, color: color, size: 20);
  }

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : inactiveColor;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTabIcon(color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? activeColor : Colors.transparent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}
