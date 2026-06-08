import 'package:flutter/material.dart';
import '../../../core/images/image_cache_managers.dart';
import '../../../core/services/sentry_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/app_network_image.dart';

/// Purple accent for dial-card pill and indeterminate progress (reference UI).
abstract final class CallDialCardColors {
  static const Color pillAndProgress = Color(0xFF7E57C2);
  static const Color progressTrack = AppPalette.outlineSoft;
}

/// Shared pre-connect call UI: gradient card, large photo right, tagline pill, status, bar, actions.
class CallDialCard extends StatelessWidget {
  /// Title line, e.g. `"Alanna, 36"` (already formatted).
  final String nameLine;

  final String? country;
  final String? imageUrl;
  final String tagline;
  final String statusText;

  /// When true, shows [CallDialConnectingBar] using [connectingBarAnimation].
  final bool showConnectingBar;
  final Animation<double>? connectingBarAnimation;

  /// Default red hang-up; hidden when false.
  final bool showHangUpButton;
  final VoidCallback? onHangUp;

  /// If non-null, replaces the default hang-up button (e.g. Accept / Reject row).
  final Widget? bottomSectionReplacement;

  final EdgeInsetsGeometry padding;
  final bool reserveStatusBarSpace;

  const CallDialCard({
    super.key,
    required this.nameLine,
    this.country,
    this.imageUrl,
    this.tagline = 'Eager to talk with you...',
    required this.statusText,
    this.showConnectingBar = false,
    this.connectingBarAnimation,
    this.showHangUpButton = true,
    this.onHangUp,
    this.bottomSectionReplacement,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 18),
    this.reserveStatusBarSpace = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppBrandGradients.callDialCard,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Padding(
          padding: padding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth;
              final photoSize = (maxW * 0.33).clamp(102.0, 150.0);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nameLine,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppPalette.onSurface,
                                    letterSpacing: 0.2,
                                  ),
                            ),
                            if (country != null &&
                                country!.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                country!.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppPalette.subtitle,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: CallDialCardColors.pillAndProgress,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  tagline,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      CallDialProfilePhoto(size: photoSize, imageUrl: imageUrl),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppPalette.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: showConnectingBar && connectingBarAnimation != null
                        ? Align(
                            key: const ValueKey('dial-connecting-bar'),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 230),
                              child: CallDialConnectingBar(
                                animation: connectingBarAnimation!,
                                trackColor: CallDialCardColors.progressTrack,
                                fillColor: CallDialCardColors.pillAndProgress,
                              ),
                            ),
                          )
                        : (reserveStatusBarSpace
                              ? const SizedBox(
                                  key: ValueKey('dial-connecting-placeholder'),
                                  height: 8,
                                )
                              : const SizedBox.shrink()),
                  ),
                  const SizedBox(height: 14),
                  if (bottomSectionReplacement != null)
                    bottomSectionReplacement!
                  else if (showHangUpButton && onHangUp != null)
                    Center(
                      child: GestureDetector(
                        onTap: onHangUp,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppPalette.primaryRed,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppPalette.primaryRed.withValues(
                                  alpha: 0.45,
                                ),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Large rounded photo, center-right emphasis (reference layout).
class CallDialProfilePhoto extends StatefulWidget {
  final double size;
  final String? imageUrl;
  final String? imageSourceTag;

  const CallDialProfilePhoto({
    super.key,
    required this.size,
    this.imageUrl,
    this.imageSourceTag,
  });

  @override
  State<CallDialProfilePhoto> createState() => _CallDialProfilePhotoState();
}

class _CallDialProfilePhotoState extends State<CallDialProfilePhoto> {
  bool _failed = false;

  @override
  void didUpdateWidget(covariant CallDialProfilePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _failed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final radius = (size * 0.16).clamp(16.0, 22.0);
    final trimmedUrl = widget.imageUrl?.trim();
    final imageUrl = (trimmedUrl == null || trimmedUrl.isEmpty)
        ? null
        : trimmedUrl;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppPalette.outlineSoft),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: imageUrl != null
            ? AppNetworkImage(
                key: ValueKey('dial-photo-$imageUrl'),
                imageUrl: imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(radius - 1),
                cacheManager: avatarCacheManager,
                placeholder: _placeholder(size, state: _PhotoState.loading),
                onImageDecoded: () {
                  if (!mounted) return;
                  setState(() {
                    _failed = false;
                  });
                },
                errorFallback: _PhotoErrorFallback(
                  size: size,
                  onShown: () {
                    if (!mounted || _failed) return;
                    _logImageFailure(imageUrl);
                    setState(() {
                      _failed = true;
                    });
                  },
                ),
                variantTag: 'callPhoto',
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(radius - 1),
                child: _placeholder(size, state: _PhotoState.empty),
              ),
      ),
    );
  }

  void _logImageFailure(String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    final firstPath = uri == null || uri.pathSegments.isEmpty
        ? ''
        : uri.pathSegments.first;
    SentryService.addBreadcrumb(
      category: 'call.avatar',
      message: 'incoming_avatar_image_load_failed',
      data: {
        'source': widget.imageSourceTag ?? 'unknown',
        'url_host': uri?.host ?? '',
        'url_path_hint': firstPath,
      },
    );
  }

  Widget _placeholder(double s, {required _PhotoState state}) {
    final icon = switch (state) {
      _PhotoState.loading => Icons.hourglass_top_rounded,
      _PhotoState.error => Icons.broken_image_outlined,
      _PhotoState.empty => Icons.person,
    };
    return ColoredBox(
      color: AppPalette.beige,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: s * 0.45, color: AppPalette.subtitle),
          if (state == _PhotoState.loading)
            SizedBox(
              width: s * 0.24,
              height: s * 0.24,
              child: const CircularProgressIndicator(strokeWidth: 2.2),
            ),
        ],
      ),
    );
  }
}

enum _PhotoState { loading, error, empty }

class _PhotoErrorFallback extends StatefulWidget {
  final double size;
  final VoidCallback onShown;

  const _PhotoErrorFallback({required this.size, required this.onShown});

  @override
  State<_PhotoErrorFallback> createState() => _PhotoErrorFallbackState();
}

class _PhotoErrorFallbackState extends State<_PhotoErrorFallback> {
  bool _reported = false;

  @override
  Widget build(BuildContext context) {
    if (!_reported) {
      _reported = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onShown();
      });
    }
    return ColoredBox(
      color: AppPalette.beige,
      child: Icon(
        Icons.broken_image_outlined,
        size: widget.size * 0.45,
        color: AppPalette.subtitle,
      ),
    );
  }
}

/// Indeterminate sliding segment (same motion as legacy outgoing overlay).
class CallDialConnectingBar extends StatelessWidget {
  final Animation<double> animation;
  final Color trackColor;
  final Color fillColor;

  const CallDialConnectingBar({
    super.key,
    required this.animation,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            const height = 7.0;
            final segmentW = maxW * 0.45;
            final travel = maxW + segmentW;
            final left = (animation.value * travel) - segmentW;

            return Container(
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: fillColor.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                color: trackColor,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned(
                    left: left,
                    top: 0,
                    bottom: 0,
                    width: segmentW,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: fillColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
