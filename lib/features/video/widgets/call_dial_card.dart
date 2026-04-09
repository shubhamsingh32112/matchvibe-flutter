import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/styles/app_brand_styles.dart';

/// Purple accent for dial-card pill and indeterminate progress (reference UI).
abstract final class CallDialCardColors {
  static const Color pillAndProgress = Color(0xFF7E57C2);
  static const Color progressTrack = Color(0xFFE8E8EC);
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
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
              final photoSize = (maxW * 0.42).clamp(120.0, 200.0);

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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppPalette.onSurface,
                                    letterSpacing: 0.2,
                                  ),
                            ),
                            if (country != null && country!.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                country!.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      CallDialProfilePhoto(
                        size: photoSize,
                        imageUrl: imageUrl,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppPalette.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (showConnectingBar &&
                      connectingBarAnimation != null) ...[
                    const SizedBox(height: 12),
                    CallDialConnectingBar(
                      animation: connectingBarAnimation!,
                      trackColor: CallDialCardColors.progressTrack,
                      fillColor: CallDialCardColors.pillAndProgress,
                    ),
                  ],
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
                                color: AppPalette.primaryRed
                                    .withValues(alpha: 0.45),
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
class CallDialProfilePhoto extends StatelessWidget {
  final double size;
  final String? imageUrl;

  const CallDialProfilePhoto({
    super.key,
    required this.size,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final radius = (size * 0.18).clamp(18.0, 28.0);
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 1),
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  errorBuilder: (_, _, _) => _placeholder(size),
                )
              : _placeholder(size),
        ),
      ),
    );
  }

  Widget _placeholder(double s) {
    return ColoredBox(
      color: AppPalette.beige,
      child: Icon(
        Icons.person,
        size: s * 0.45,
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
            const height = 8.0;
            final segmentW = maxW * 0.42;
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
