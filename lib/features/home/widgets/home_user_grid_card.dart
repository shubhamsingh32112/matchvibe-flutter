import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/creator_model.dart';
import '../../../shared/models/profile_model.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/services/chat_service.dart';
import '../providers/availability_provider.dart';
import '../../video/controllers/call_connection_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/avatar_upload_service.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/coin_purchase_popup.dart';
import '../../../shared/widgets/app_modal_bottom_sheet.dart';
import '../../../shared/widgets/brand_app_chrome.dart';

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

  /// PHASE 2: Show modal for insufficient coins
  void _showInsufficientCoinsModal() {
    showAppModalBottomSheet(
      context: context,
      builder: (context) => const CoinPurchaseBottomSheet(),
    );
  }

  void _openCreatorProfileModal({required bool isCreatorOnline}) {
    if (widget.creator == null) return;
    showAppModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.68,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) => _CreatorProfileBottomSheet(
          creator: widget.creator!,
          isOnline: isCreatorOnline,
          scrollController: scrollController,
          onCallPressed: _isInitiatingCall
              ? null
              : () {
                  Navigator.of(sheetContext).pop();
                  _initiateVideoCall();
                },
          isCalling: _isInitiatingCall,
          onChatPressed: _isOpeningChat
              ? null
              : () {
                  Navigator.of(sheetContext).pop();
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
      final result =
          await chatService.createOrGetChannel(creator.userId);
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
    ref.listen<CallConnectionState>(callConnectionControllerProvider,
        (prev, next) {
      if (_isInitiatingCall &&
          next.phase == CallConnectionPhase.failed &&
          next.error != null) {
        if (mounted) {
          AppToast.showError(context, next.error!);
        }
      }
    });

    final scheme = Theme.of(context).colorScheme;

    final String title = widget.creator?.name ?? widget.user?.username ?? 'User';
    final age = _creatorAge();
    final country = _creatorCountry();
    final authState = ref.watch(authProvider);
    final isRegularUser = authState.user?.role == 'user';
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
                  child: _CardImage(creator: widget.creator, user: widget.user)),
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
              if (showVideoCall)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: AppSpacing.lg,
                  child: Center(
                    child: _VideoCallButton(
                      isLoading: _isInitiatingCall,
                      onPressed: isCreatorOnline ? _initiateVideoCall : null,
                      disabled: !isCreatorOnline,
                    ),
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
    final effectiveDisabled = disabled || onPressed == null;
    const double buttonSize = 56;
    const double iconSize = 26;
    final brand = AppBrandGradients.userHomeVideoCall;

    return Material(
      color: effectiveDisabled
          ? brand.withValues(alpha: 0.42)
          : brand.withValues(alpha: 0.95),
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
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    Icons.videocam,
                    color: effectiveDisabled
                        ? Colors.white.withValues(alpha: 0.72)
                        : Colors.white,
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
              fontSize: 10,
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

class _CreatorProfileBottomSheet extends StatelessWidget {
  final CreatorModel creator;
  final bool isOnline;
  final ScrollController scrollController;
  final VoidCallback? onCallPressed;
  final bool isCalling;
  final VoidCallback? onChatPressed;
  final bool isOpeningChat;
  final String country;
  final int age;

  const _CreatorProfileBottomSheet({
    required this.creator,
    required this.isOnline,
    required this.scrollController,
    required this.onCallPressed,
    required this.isCalling,
    required this.onChatPressed,
    required this.isOpeningChat,
    required this.country,
    required this.age,
  });

  List<String> _orderedGalleryUrls() {
    final sorted = List<CreatorGalleryImage>.from(creator.galleryImages)
      ..sort((a, b) => a.position.compareTo(b.position));
    return sorted
        .map((e) => e.url.trim())
        .where((u) => u.isNotEmpty)
        .toList();
  }

  void _openGalleryImage(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => _CreatorGalleryImageViewer(url: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final galleryUrls = _orderedGalleryUrls();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: ColoredBox(
        color: AppBrandGradients.accountMenuPageBackground,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BrandSheetHeader(
              title: creator.name,
              trailing: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
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
                        child: ClipOval(
                          child: SizedBox(
                            width: 100,
                            height: 100,
                            child: Image.network(
                              creator.photo,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return ColoredBox(
                                  color: scheme.surfaceContainerHigh,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, _, _) => ColoredBox(
                                color: scheme.surfaceContainerHigh,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Center(
                        child: Text(
                          isOnline ? '● Online' : '● Busy',
                          style: TextStyle(
                            color: isOnline
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
                          '${creator.name} $age',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Center(
                        child: Text(
                          country,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
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
                      Text(
                        creator.about.isNotEmpty
                            ? creator.about
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
                      if (galleryUrls.isEmpty)
                        Text(
                          'no pictures added',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: scheme.onSurfaceVariant),
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
                          itemCount: galleryUrls.length,
                          itemBuilder: (context, index) {
                            final url = galleryUrls[index];
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _openGalleryImage(context, url),
                                borderRadius: BorderRadius.circular(14),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) {
                                        return child;
                                      }
                                      return ColoredBox(
                                        color: scheme.surfaceContainerHigh,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, _, _) => ColoredBox(
                                      color: scheme.surfaceContainerHigh,
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
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
                        onPressed: isOpeningChat ? null : onChatPressed,
                        icon: isOpeningChat
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
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
                        onPressed: isOnline ? onCallPressed : null,
                        icon: isCalling
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.videocam),
                        label: const Text('Video Call'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppBrandGradients.userHomeVideoCall,
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
class _CreatorGalleryImageViewer extends StatelessWidget {
  final String url;

  const _CreatorGalleryImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
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
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const SizedBox(
                height: 120,
                width: 120,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                ),
              );
            },
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
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
