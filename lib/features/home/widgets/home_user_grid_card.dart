import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/images/image_cache_managers.dart';
import '../../../core/services/image_precache_service.dart';
import '../../../core/services/meta_app_events_service.dart';
import '../../video/utils/call_admission_constants.dart';
import '../../../shared/models/creator_model.dart';
import '../../../shared/models/profile_model.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/services/chat_service.dart';
import '../providers/availability_provider.dart';
import '../../video/controllers/call_connection_controller.dart';
import 'call_button_variant.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../../shared/providers/coin_purchase_popup_provider.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/creator_price_per_minute_label.dart';
import 'creator_profile_screen.dart';

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

  String? _normalizedFirebaseUid(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Initiate a video call to the creator via [CallConnectionController].
  ///
  /// All call logic (permissions, getOrCreate, join, navigation) is
  /// handled by the controller — the card only triggers it.
  Future<void> _initiateVideoCall() async {
    if (widget.creator == null || _isInitiatingCall) return;

    final creatorFirebaseUid = _normalizedFirebaseUid(widget.creator!.firebaseUid);
    if (creatorFirebaseUid == null) {
      if (mounted) {
        AppToast.showError(context, 'Creator information not available');
      }
      return;
    }

    // PHASE 2: Check coins before initiating call
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user != null && user.spendableCallCoins < kMinCoinsToCall) {
      if (mounted) {
        final c = widget.creator!;
        final fb = _normalizedFirebaseUid(c.firebaseUid);
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

  void _openCreatorProfileModal({required CreatorAvailability creatorAvailability}) {
    if (widget.creator == null) return;
    final creatorId = widget.creator!.id;
    unawaited(
      MetaAppEventsService.logViewContent(
        contentId: creatorId,
        contentType: 'creator_profile',
      ),
    );
    ImagePrecacheService.precacheCreatorGallery(context, widget.creator!);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (pageContext) => CreatorProfileScreen(
          creatorId: creatorId,
          initialCreator: widget.creator!,
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
    final userRole = ref.watch(authProvider.select((s) => s.user?.role));
    final welcomeFreeCallEligible = ref.watch(
      authProvider.select((s) => s.user?.welcomeFreeCallEligible == true),
    );
    final isRegularUser = userRole == 'user';
    final showVideoCall = isRegularUser && widget.creator != null;
    final callVariant = welcomeFreeCallEligible
        ? CallButtonVariant.welcomeFree
        : CallButtonVariant.normal;

    // ── Availability (only relevant for creator cards) ────────────────────
    final creatorFirebaseUid = _normalizedFirebaseUid(widget.creator?.firebaseUid);
    final hasHydratedLiveStatus = ref.watch(
      creatorAvailabilityProvider.select((map) {
        if (creatorFirebaseUid == null || creatorFirebaseUid.isEmpty) {
          return false;
        }
        return map.containsKey(creatorFirebaseUid);
      }),
    );
    final liveAvailability = ref.watch(creatorStatusProvider(creatorFirebaseUid));
    final seededAvailability = widget.creator?.availability == 'online'
        ? CreatorAvailability.online
        : widget.creator?.availability == 'on_call'
        ? CreatorAvailability.onCall
        : CreatorAvailability.offline;
    final effectiveAvailability = hasHydratedLiveStatus
        ? liveAvailability
        : seededAvailability;
    final isCreatorOnline = effectiveAvailability == CreatorAvailability.online;

    return SizedBox.expand(
      child: AppCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.zero,
      child: InkWell(
        borderRadius: BorderRadius.zero,
        onTap: widget.creator != null
            ? () => _openCreatorProfileModal(creatorAvailability: effectiveAvailability)
            : null,
        child: ClipRect(
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
                  child: _AvailabilityTag(availability: effectiveAvailability),
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
                            iconSize: 18,
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
  final CreatorAvailability availability;

  const _AvailabilityTag({required this.availability});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: availability == CreatorAvailability.online
            ? AppPalette.success.withValues(alpha: 0.92)
            : availability == CreatorAvailability.onCall
            ? AppPalette.warning.withValues(alpha: 0.92)
            : AppPalette.subtitle.withValues(alpha: 0.92),
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
            availability == CreatorAvailability.online
                ? 'Online'
                : availability == CreatorAvailability.onCall
                ? 'On call'
                : 'Offline',
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
    final titleStyle = GoogleFonts.lexend(
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

class _CardImage extends StatelessWidget {
  final CreatorModel? creator;
  final UserProfileModel? user;

  const _CardImage({required this.creator, required this.user});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (width <= 0 || height <= 0) {
          return const SizedBox.shrink();
        }

        final c = creator;
        if (c != null) {
          return AppNetworkImage(
            imageUrl: c.feedTileUrl,
            width: width,
            height: height,
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
          size: math.min(width, height),
          isCircular: false,
          borderRadius: BorderRadius.zero,
          fallbackText: u.username?.isNotEmpty == true
              ? u.username![0]
              : 'U',
        );
      },
    );
  }
}
