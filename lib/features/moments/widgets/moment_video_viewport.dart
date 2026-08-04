import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../utils/moment_video_fit.dart';

/// Full-bleed Moments video surface: fills the parent, picks cover vs contain
/// from [resolveMomentVideoFit], and clips overflow.
class MomentVideoViewport extends StatelessWidget {
  const MomentVideoViewport({
    super.key,
    required this.controller,
    this.backgroundColor = Colors.black,
  });

  final VideoPlayerController controller;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          if (!value.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          final videoSize = value.size;
          final w = videoSize.width;
          final h = videoSize.height;
          if (!w.isFinite || !h.isFinite || w <= 0 || h <= 0) {
            // Fall back to aspectRatio when platform size is unset.
            final ar = value.aspectRatio;
            if (!ar.isFinite || ar <= 0) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final viewport = _viewportSize(context, constraints);
                final fallback = Size(ar * 1000, 1000);
                final fit = resolveMomentVideoFit(
                  video: fallback,
                  viewport: viewport,
                );
                return SizedBox.expand(
                  child: FittedBox(
                    fit: fit,
                    clipBehavior: Clip.hardEdge,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: fallback.width,
                      height: fallback.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
                );
              },
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final viewport = _viewportSize(context, constraints);
              final fit = resolveMomentVideoFit(
                video: Size(w, h),
                viewport: viewport,
              );
              return SizedBox.expand(
                child: FittedBox(
                  fit: fit,
                  clipBehavior: Clip.hardEdge,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: VideoPlayer(controller),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static Size _viewportSize(BuildContext context, BoxConstraints constraints) {
    final mq = MediaQuery.sizeOf(context);
    final width = constraints.maxWidth.isFinite && constraints.maxWidth > 0
        ? constraints.maxWidth
        : mq.width;
    final height = constraints.maxHeight.isFinite && constraints.maxHeight > 0
        ? constraints.maxHeight
        : mq.height;
    return Size(width, height);
  }
}
