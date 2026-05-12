import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/images/image_cache_managers.dart';
import '../../../core/services/image_precache_service.dart';
import '../../../shared/models/creator_model.dart';
import '../../../shared/models/profile_model.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/services/chat_service.dart';
import '../providers/availability_provider.dart';
import '../providers/home_provider.dart';
import '../../video/controllers/call_connection_controller.dart';
import 'call_button_variant.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../../shared/providers/coin_purchase_popup_provider.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../../../shared/widgets/creator_price_per_minute_label.dart';

class HomeUserGridCard extends ConsumerStatefulWidget {
  final CreatorModel? creator;
  final UserProfileModel? user;

  const HomeUserGridCard({super.key, this.creator, this.user})
    : assert(
        creator != null || user != null,
        'Either creator or user must be provided',
      );

  @override
  ConsumerState<HomeUserGridCard> createState() => _HomeUserGridCardState();
}

class _HomeUserGridCardState extends ConsumerState<HomeUserGridCard> {
  bool _isInitiatingCall = false;
  bool _isOpeningChat = false;

  /// Initiate a video call to the creator via [CallConnectionController].
  ///
  /// All call logic (permissions, getOrCreate, join, navigation) is
  /// handled by the controller — the card only triggers it.
  Future<void> _initiateVideoCall() async {
    if (widget.creator == null || _isInitiatingCall) return;

    final creatorFirebaseUid = widget.creator!.firebaseUid;
    if (creatorFirebaseUid == null) {
      if (mounted) {
        AppToast.showError(context, 'Creator information not available');
      }
      return;
    }

    // PHASE 2: Check coins before initiating call
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user != null && user.spendableCallCoins < 10) {
      if (mounted) {
        final c = widget.creator!;
        final fb = c.firebaseUid;
        ref.read(coinPurchasePopupProvider.notifier).state = CoinPopupIntent(
          reason: 'preflight_low_coins_grid',
          dedupeKey: 'low-coins-grid-${c.id}',
          remoteDisplayName: c.name,
          remotePhotoUrl: c.feedTileUrl,
          remoteFirebaseUid: fb,
        );
      }
      return;
    }

    setState(() {
      _isInitiatingCall = true;
    });

    try {
      await ref
          .read(callConnectionControllerProvider.notifier)
          .startUserCall(
            creatorFirebaseUid: creatorFirebaseUid,
            creatorMongoId: widget.creator!.id,
            creatorImageUrl: widget.creator!.feedTileUrl,
            creatorName: widget.creator!.name,
            creatorAge: _creatorAge(),
            creatorCountry: _creatorCountry(),
          );
    } finally {
      if (mounted) {
        setState(() {
          _isInitiatingCall = false;
        });
      }
    }
  }

  void _openCreatorProfileModal({required bool isCreatorOnline}) {
    if (widget.creator == null) return;
    final u = ref.read(authProvider).user;
    final modalCallVariant = u?.welcomeFreeCallEligible == true
        ? CallButtonVariant.welcomeFree
        : CallButtonVariant.normal;
    ImagePrecacheService.precacheCreatorGallery(context, widget.creator!);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (pageContext) => _CreatorProfilePage(
          callVariant: modalCallVariant,
          creator: widget.creator!,
          isOnline: isCreatorOnline,
          onCallPressed: _isInitiatingCall
              ? null
              : () {
                  Navigator.of(pageContext).pop();
                  _initiateVideoCall();
                },
          isCalling: _isInitiatingCall,
          onChatPressed: _isOpeningChat
              ? null
              : () {
                  Navigator.of(pageContext).pop();
                  _openCreatorChat();
                },
          isOpeningChat: _isOpeningChat,
          country: _creatorCountry(),
          age: _creatorAge(),
        ),
      ),
    );
  }

  Future<void> _openCreatorChat() async {
    final creator = widget.creator;
    if (creator == null || _isOpeningChat) return;

    setState(() => _isOpeningChat = true);
    try {
      final chatService = ChatService();
      // Backend resolves User by Mongo id — use creator's User document id, not Creator profile id.
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
      if (mounted) {
        setState(() => _isOpeningChat = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for call connection failures to show error SnackBars.
    // Only this card reacts (guarded by _isInitiatingCall).
    ref.listen<CallConnectionState>(callConnectionControllerProvider, (
      prev,
      next,
    ) {
      if (_isInitiatingCall &&
          next.phase == CallConnectionPhase.failed &&
          next.error != null) {
        if (mounted) {
          AppToast.showError(context, next.error!);
        }
      }
    });

    final scheme = Theme.of(context).colorScheme;

    final String title =
        widget.creator?.name ?? widget.user?.username ?? 'User';
    final age = _creatorAge();
    final country = _creatorCountry();
    final authState = ref.watch(authProvider);
    final isRegularUser = authState.user?.role == 'user';
    final showVideoCall = isRegularUser && widget.creator != null;
    final callVariant = authState.user?.welcomeFreeCallEligible == true
        ? CallButtonVariant.welcomeFree
        : CallButtonVariant.normal;

    // ── Availability (only relevant for creator cards) ────────────────────
    final creatorAvailability = ref.watch(
      creatorStatusProvider(widget.creator?.firebaseUid),
    );
    final isCreatorOnline = creatorAvailability == CreatorAvailability.online;

    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.creator != null
            ? () => _openCreatorProfileModal(isCreatorOnline: isCreatorOnline)
            : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: _CardImage(creator: widget.creator, user: widget.user),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppBrandGradients.userCardOverlay(scheme),
                  ),
                ),
              ),
              Positioned(
                top: AppSpacing.md,
                left: AppSpacing.md,
                child: _CreatorInfoText(
                  name: title,
                  age: age,
                  country: country,
                  textColor: Colors.white,
                ),
              ),
              if (widget.creator != null)
                Positioned(
                  top: AppSpacing.md,
                  right: AppSpacing.md,
                  child: _AvailabilityTag(isOnline: isCreatorOnline),
                ),
              if (widget.creator != null)
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.lg,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: CreatorPricePerMinuteLabel(
                            price: widget.creator!.price,
                            expandText: true,
                            overflow: TextOverflow.ellipsis,
                            iconSize: 14,
                            iconColor: Colors.white,
                            textStyle: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  height: 1.2,
                                ),
                          ),
                        ),
                      ),
                      if (showVideoCall)
                        _VideoCallButton(
                          variant: callVariant,
                          isLoading: _isInitiatingCall,
                          onPressed: isCreatorOnline
                              ? _initiateVideoCall
                              : null,
                          disabled: !isCreatorOnline,
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

  int _creatorAge() {
    final creator = widget.creator;
    if (creator == null) return 24;

    // Use the actual age field from the creator model
    if (creator.age != null) {
      return creator.age!;
    }

    // Fallback: if age is not available, try to infer from text (legacy support)
    final source = '${creator.name} ${creator.about}';
    final match = RegExp(r'\b(1[89]|[2-9]\d)\b').firstMatch(source);
    if (match == null) return 24;
    return int.tryParse(match.group(0) ?? '') ?? 24;
  }

  String _creatorCountry() {
    return 'India';
  }
}

/// Video call FAB on home creator tiles: optional heartbeat scale when tappable.
class _VideoCallButton extends StatefulWidget {
  final CallButtonVariant variant;
  final bool isLoading;
  final VoidCallback? onPressed;
  final bool disabled;

  const _VideoCallButton({
    required this.variant,
    required this.isLoading,
    this.onPressed,
    this.disabled = false,
  });

  @override
  State<_VideoCallButton> createState() => _VideoCallButtonState();
}

class _VideoCallButtonState extends State<_VideoCallButton>
    with SingleTickerProviderStateMixin {
  static const double _buttonSize = 56;
  static const double _iconSize = 26;

  late final AnimationController _heartbeatController;
  late final Animation<double> _heartbeatScale;

  @override
  void initState() {
    super.initState();
    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _heartbeatScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.12,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.12,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 11,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.08,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 11,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 50),
    ]).animate(_heartbeatController);
  }

  void _syncHeartbeat() {
    final effectiveDisabled = widget.disabled || widget.onPressed == null;
    final shouldPulse =
        !effectiveDisabled &&
        !widget.isLoading &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

    if (shouldPulse) {
      if (!_heartbeatController.isAnimating) {
        _heartbeatController.repeat();
      }
    } else {
      _heartbeatController.stop();
      _heartbeatController.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncHeartbeat();
  }

  @override
  void didUpdateWidget(_VideoCallButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncHeartbeat();
  }

  @override
  void dispose() {
    _heartbeatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDisabled = widget.disabled || widget.onPressed == null;
    final normalBrand = AppBrandGradients.userHomeVideoCall;
    final welcomeGreen = AppPalette.success;
    final useWelcome = widget.variant.showWelcomePromo;
    final shouldPulse =
        !effectiveDisabled &&
        !widget.isLoading &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false) &&
        (Scrollable.recommendDeferredLoadingForContext(context) == false);

    Widget button = Material(
      color: effectiveDisabled
          ? (useWelcome ? welcomeGreen : normalBrand).withValues(alpha: 0.42)
          : (useWelcome ? welcomeGreen : normalBrand).withValues(
              alpha: useWelcome ? 1 : 0.95,
            ),
      shape: const CircleBorder(
        side: BorderSide(color: Colors.white, width: 1),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: widget.isLoading || effectiveDisabled ? null : widget.onPressed,
        child: SizedBox(
          width: _buttonSize,
          height: _buttonSize,
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: _iconSize,
                    height: _iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  )
                : useWelcome
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.rotate(
                        angle: -0.785,
                        child: Icon(
                          Icons.phone,
                          color: effectiveDisabled
                              ? Colors.white.withValues(alpha: 0.72)
                              : Colors.white,
                          size: 20,
                        ),
                      ),
                      Text(
                        widget.variant.stackedPromoLine,
                        style: TextStyle(
                          color: effectiveDisabled
                              ? Colors.white.withValues(alpha: 0.72)
                              : Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      Text(
                        widget.variant.stackedPromoLine,
                        style: TextStyle(
                          color: effectiveDisabled
                              ? Colors.white.withValues(alpha: 0.72)
                              : Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ],
                  )
                : Icon(
                    Icons.videocam,
                    color: effectiveDisabled
                        ? Colors.white.withValues(alpha: 0.72)
                        : Colors.white,
                    size: _iconSize,
                  ),
          ),
        ),
      ),
    );

    if (shouldPulse) {
      button = AnimatedBuilder(
        animation: _heartbeatScale,
        builder: (context, child) {
          return Transform.scale(
            scale: _heartbeatScale.value,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: button,
      );
    }

    return button;
  }
}

// ── Availability tag (Online / Busy) ──────────────────────────────────────
class _AvailabilityTag extends StatelessWidget {
  final bool isOnline;

  const _AvailabilityTag({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOnline
            ? AppPalette.success.withValues(alpha: 0.92)
            : AppPalette.warning.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isOnline ? 'Online' : 'Busy',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatorInfoText extends StatelessWidget {
  final String name;
  final int age;
  final String country;
  final Color textColor;

  const _CreatorInfoText({
    required this.name,
    required this.age,
    required this.country,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: textColor,
      fontWeight: FontWeight.w700,
      height: 1.12,
      fontSize: 13,
    );
    final subtitleStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: textColor,
      fontSize: 11,
      height: 1.2,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$name $age',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: titleStyle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          country,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: subtitleStyle,
        ),
      ],
    );
  }
}

class _CreatorProfilePage extends ConsumerStatefulWidget {
  final CallButtonVariant callVariant;
  final CreatorModel creator;
  final bool isOnline;
  final VoidCallback? onCallPressed;
  final bool isCalling;
  final VoidCallback? onChatPressed;
  final bool isOpeningChat;
  final String country;
  final int age;

  const _CreatorProfilePage({
    required this.callVariant,
    required this.creator,
    required this.isOnline,
    required this.onCallPressed,
    required this.isCalling,
    required this.onChatPressed,
    required this.isOpeningChat,
    required this.country,
    required this.age,
  });

  @override
  ConsumerState<_CreatorProfilePage> createState() => _CreatorProfilePageState();
}

class _CreatorProfilePageState extends ConsumerState<_CreatorProfilePage> {
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

  void _openGalleryImage(
    BuildContext context,
    String fullUrl, {
    String? blurhash,
    String? heroTag,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => _CreatorGalleryImageViewer(
          url: fullUrl,
          blurhash: blurhash,
          heroTag: heroTag,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detailAsync = ref.watch(creatorDetailProvider(widget.creator.id));
    final merged = detailAsync.maybeWhen(
      data: (d) => widget.creator.copyWith(
        about: d.about,
        galleryImages: d.galleryImages,
        avatar: d.avatar,
      ),
      orElse: () => widget.creator,
    );

    final galleryItems = _galleryItems(merged);
    final galleryLoading =
        detailAsync.isLoading && widget.creator.galleryImages.isEmpty;
    // memCacheWidth/Height now computed inside AppNetworkImage / AppAvatar.

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
                        fallbackText: merged.name.isNotEmpty
                            ? merged.name[0]
                            : 'C',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: Text(
                        widget.isOnline ? '● Online' : '● Busy',
                        style: TextStyle(
                          color: widget.isOnline
                              ? AppPalette.success
                              : AppPalette.warning,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: Text(
                        '${merged.name} ${widget.age}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Center(
                      child: Text(
                        widget.country,
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
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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
                    Text(
                      'Pictures',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (galleryLoading)
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
                              onTap: () => _openGalleryImage(
                                context,
                                item.fullUrl,
                                blurhash: item.blurhash,
                                heroTag: item.heroTag,
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
                        onPressed:
                            widget.isOpeningChat ? null : widget.onChatPressed,
                        icon: widget.isOpeningChat
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
                        onPressed: widget.isOnline ? widget.onCallPressed : null,
                        icon: widget.isCalling
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                widget.callVariant.showWelcomePromo
                                    ? Icons.phone
                                    : Icons.videocam,
                              ),
                        label: Text(
                          widget.callVariant.showWelcomePromo
                              ? 'Free intro call'
                              : 'Video Call',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              widget.callVariant.showWelcomePromo
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

/// Full-screen gallery image with pinch-zoom.
/// Uses the `galleryXl` variant (1600x1600 contain), NOT true original —
/// keeps memory + bandwidth bounded.
class _CreatorGalleryImageViewer extends StatelessWidget {
  final String url;
  final String? blurhash;
  final String? heroTag;

  const _CreatorGalleryImageViewer({
    required this.url,
    this.blurhash,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: AppNetworkImage(
            imageUrl: url,
            width: size.width,
            height: size.height,
            fit: BoxFit.contain,
            blurhash: blurhash,
            heroTag: heroTag,
            cacheManager: galleryCacheManager,
            errorIcon: Icons.broken_image_outlined,
            variantTag: 'galleryXl',
          ),
        ),
      ),
    );
  }
}

class _CardImage extends StatelessWidget {
  final CreatorModel? creator;
  final UserProfileModel? user;

  const _CardImage({required this.creator, required this.user});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final tileWidth = math.max(120.0, width / 2);
    final tileHeight = math.max(180.0, tileWidth * 1.4);

    final c = creator;
    if (c != null) {
      return AppNetworkImage(
        imageUrl: c.feedTileUrl,
        width: tileWidth,
        height: tileHeight,
        fit: BoxFit.cover,
        blurhash: c.avatarBlurhash,
        cacheManager: feedCacheManager,
        heroTag: 'creator-feed-${c.id}',
        variantTag: 'feedTile',
      );
    }

    final u = user;
    if (u == null) {
      final scheme = Theme.of(context).colorScheme;
      return DecoratedBox(
        decoration: BoxDecoration(color: scheme.surfaceContainerHigh),
      );
    }

    return AppAvatar(
      avatarAsset: u.avatarAsset,
      size: math.min(tileWidth, tileHeight),
      isCircular: false,
      borderRadius: BorderRadius.zero,
      fallbackText: u.username?.isNotEmpty == true
          ? u.username![0]
          : 'U',
    );
  }

}
