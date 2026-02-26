import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/creator_model.dart';
import '../../../shared/models/profile_model.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/api/api_client.dart';
import '../../chat/services/chat_service.dart';
import '../providers/home_provider.dart';
import '../providers/availability_provider.dart';
import '../../video/controllers/call_connection_controller.dart';
import '../../../core/services/avatar_upload_service.dart';

class HomeUserGridCard extends ConsumerStatefulWidget {
  final CreatorModel? creator;
  final UserProfileModel? user;

  const HomeUserGridCard({
    super.key,
    this.creator,
    this.user,
  }) : assert(creator != null || user != null, 'Either creator or user must be provided');

  @override
  ConsumerState<HomeUserGridCard> createState() => _HomeUserGridCardState();
}

class _HomeUserGridCardState extends ConsumerState<HomeUserGridCard> {
  bool _isInitiatingCall = false;
  bool _isOpeningChat = false;

  /// Open a chat channel with the creator.
  Future<void> _openChat() async {
    if (widget.creator == null || _isOpeningChat) return;

    final creatorFirebaseUid = widget.creator!.firebaseUid;
    if (creatorFirebaseUid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Creator information not available'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isOpeningChat = true);

    try {
      final chatService = ChatService();
      final result = await chatService.createOrGetChannel(creatorFirebaseUid);
      final channelId = result['channelId'] as String?;

      if (channelId != null && mounted) {
        context.push('/chat/$channelId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningChat = false);
    }
  }

  /// Initiate a video call to the creator via [CallConnectionController].
  ///
  /// All call logic (permissions, getOrCreate, join, navigation) is
  /// handled by the controller — the card only triggers it.
  Future<void> _initiateVideoCall() async {
    if (widget.creator == null || _isInitiatingCall) return;

    final creatorFirebaseUid = widget.creator!.firebaseUid;
    if (creatorFirebaseUid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Creator information not available'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // PHASE 2: Check coins before initiating call
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user != null && user.coins < 10) {
      if (mounted) {
        _showInsufficientCoinsModal();
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
            creatorImageUrl: widget.creator!.photo,
          );
    } finally {
      if (mounted) {
        setState(() {
          _isInitiatingCall = false;
        });
      }
    }
  }

  /// PHASE 2: Show modal for insufficient coins
  void _showInsufficientCoinsModal() {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.read(authProvider);
    final user = authState.user;
    final coins = user?.coins ?? 0;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: scheme.error),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Insufficient Coins'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Minimum 10 coins required to start a call.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'You currently have $coins coins.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to wallet/buy coins screen
              // For now, show a snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Navigate to wallet to buy coins'),
                  backgroundColor: scheme.primaryContainer,
                  action: SnackBarAction(
                    label: 'OK',
                    textColor: scheme.onPrimaryContainer,
                    onPressed: () {},
                  ),
                ),
              );
            },
            child: const Text('Buy Coins'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for call connection failures to show error SnackBars.
    // Only this card reacts (guarded by _isInitiatingCall).
    ref.listen<CallConnectionState>(callConnectionControllerProvider,
        (prev, next) {
      if (_isInitiatingCall &&
          next.phase == CallConnectionPhase.failed &&
          next.error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.error!),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });

    final scheme = Theme.of(context).colorScheme;

    final String title = widget.creator?.name ?? widget.user?.username ?? 'User';
    final age = _creatorAge();
    final authState = ref.watch(authProvider);
    final isRegularUser = authState.user?.role == 'user';
    final showFavorite = isRegularUser && widget.creator != null;
    final showVideoCall = isRegularUser && widget.creator != null;

    // ── Availability (only relevant for creator cards) ────────────────────
    final availabilityMap = ref.watch(creatorAvailabilityProvider);
    final creatorAvailability = widget.creator?.firebaseUid != null
        ? (availabilityMap[widget.creator!.firebaseUid!] ??
            CreatorAvailability.busy)
        : CreatorAvailability.busy;
    final isCreatorOnline = creatorAvailability == CreatorAvailability.online;

    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(child: _CardImage(creator: widget.creator, user: widget.user)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppBrandGradients.userCardOverlay(scheme),
                ),
              ),
            ),
            // ── Availability tag (top-left) ────────────────────────────────
            if (widget.creator != null)
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                child: _AvailabilityTag(isOnline: isCreatorOnline),
              ),
            if (showFavorite)
              Positioned(
                top: AppSpacing.md,
                right: AppSpacing.md,
                child: _FavoriteButton(
                  isFavorite: widget.creator!.isFavorite,
                  onPressed: () async {
                    try {
                      final apiClient = ApiClient();
                      await apiClient.post('/user/favorites/${widget.creator!.id}');
                      // Refresh feed to get updated isFavorite flags
                      ref.invalidate(creatorsProvider);
                      ref.invalidate(homeFeedProvider);
                    } catch (_) {
                      // Non-blocking: if request fails, UI will resync on next refresh.
                    }
                  },
                ),
              ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _CreatorInfoText(
                      name: title,
                      age: age,
                      textColor: scheme.onSurface,
                    ),
                  ),
                  if (showVideoCall) ...[
                    const SizedBox(width: AppSpacing.md),
                    _ChatActionButton(
                      isLoading: _isOpeningChat,
                      onPressed: _openChat,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _VideoCallButton(
                      isLoading: _isInitiatingCall,
                      // Only allow calling if creator is online
                      onPressed: isCreatorOnline ? _initiateVideoCall : null,
                      disabled: !isCreatorOnline,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _creatorAge() {
    final creator = widget.creator;
    if (creator == null) return 24;

    // Age is not explicit in the model yet, so infer from available text.
    final source = '${creator.name} ${creator.about}';
    final match = RegExp(r'\b(1[89]|[2-9]\d)\b').firstMatch(source);
    if (match == null) return 24;
    return int.tryParse(match.group(0) ?? '') ?? 24;
  }
}

class _ChatActionButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _ChatActionButton({
    required this.isLoading,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const double buttonSize = 38;
    const double iconSize = 19;

    return Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                    ),
                  )
                : Icon(
                    Icons.chat_bubble_outline,
                    color: scheme.primary,
                    size: iconSize,
                  ),
          ),
        ),
      ),
    );
  }
}

class _VideoCallButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final bool disabled;

  const _VideoCallButton({
    required this.isLoading,
    this.onPressed,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveDisabled = disabled || onPressed == null;
    const double buttonSize = 38;
    const double iconSize = 19;

    return Material(
      color: effectiveDisabled
          ? scheme.surfaceContainerHigh.withValues(alpha: 0.6)
          : scheme.primary.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: isLoading || effectiveDisabled ? null : onPressed,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(scheme.onPrimary),
                    ),
                  )
                : Icon(
                    Icons.videocam,
                    color: effectiveDisabled
                        ? scheme.onSurface.withValues(alpha: 0.4)
                        : scheme.onPrimary,
                    size: iconSize,
                  ),
          ),
        ),
      ),
    );
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
            ? Colors.green.withValues(alpha: 0.9)
            : Colors.orange.withValues(alpha: 0.9),
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
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onPressed;

  const _FavoriteButton({required this.isFavorite, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? scheme.error : scheme.onSurface,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _CreatorInfoText extends StatelessWidget {
  final String name;
  final int age;
  final Color textColor;

  const _CreatorInfoText({
    required this.name,
    required this.age,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
          height: 1.12,
        );
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: textColor,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 2,
          softWrap: true,
          overflow: TextOverflow.fade,
          style: titleStyle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          age.toString(),
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
    final creatorPhoto = creator?.photo;
    if (creator != null) {
      // Creators must use Firebase/network image only.
      if (creatorPhoto != null &&
          creatorPhoto.isNotEmpty &&
          (creatorPhoto.startsWith('http://') ||
              creatorPhoto.startsWith('https://') ||
              creatorPhoto.startsWith('data:'))) {
        return Image.network(
          creatorPhoto,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            final scheme = Theme.of(context).colorScheme;
            return DecoratedBox(
                decoration: BoxDecoration(color: scheme.surfaceContainerHigh));
          },
        );
      }
      final scheme = Theme.of(context).colorScheme;
      return DecoratedBox(
          decoration: BoxDecoration(color: scheme.surfaceContainerHigh));
    }

    final avatarStr = user?.avatar;
    if (avatarStr == null || avatarStr.isEmpty) {
      // Fallback to a semantic surface tone (no hardcoded colors).
      final scheme = Theme.of(context).colorScheme;
      return DecoratedBox(decoration: BoxDecoration(color: scheme.surfaceContainerHigh));
    }

    if (avatarStr.startsWith('http://') ||
        avatarStr.startsWith('https://') ||
        avatarStr.startsWith('data:')) {
      return Image.network(
        avatarStr,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          final scheme = Theme.of(context).colorScheme;
          return DecoratedBox(decoration: BoxDecoration(color: scheme.surfaceContainerHigh));
        },
      );
    }

    // Treat as a preset avatar key and resolve via Firebase Storage.
    final gender = user?.gender ?? 'male';
    final safeGender = gender == 'female' ? 'female' : 'male';
    return FutureBuilder<String>(
      future: _resolvePresetAvatarUrl(avatarStr, safeGender),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          final scheme = Theme.of(context).colorScheme;
          return DecoratedBox(
              decoration: BoxDecoration(color: scheme.surfaceContainerHigh));
        }
        final resolvedUrl = snapshot.data;
        if (resolvedUrl == null || resolvedUrl.isEmpty) {
          final scheme = Theme.of(context).colorScheme;
          return DecoratedBox(
              decoration: BoxDecoration(color: scheme.surfaceContainerHigh));
        }
        return Image.network(
          resolvedUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            final scheme = Theme.of(context).colorScheme;
            return DecoratedBox(
                decoration: BoxDecoration(color: scheme.surfaceContainerHigh));
          },
        );
      },
    );
  }

  Future<String> _resolvePresetAvatarUrl(String avatar, String gender) async {
    try {
      return await AvatarUploadService.getPresetAvatarUrl(
        avatarName: avatar,
        gender: gender,
      );
    } catch (_) {
      final defaultAvatar = AvatarUploadService.getDefaultAvatarName(gender);
      try {
        return await AvatarUploadService.getPresetAvatarUrl(
          avatarName: defaultAvatar,
          gender: gender,
        );
      } catch (_) {
        return '';
      }
    }
  }
}
