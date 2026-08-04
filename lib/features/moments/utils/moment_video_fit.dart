import 'dart:ui' show Size;

import 'package:flutter/painting.dart' show BoxFit;

/// How Moments / stories video should scale inside a viewport.
///
/// - Portrait & square (and landscape-on-landscape): [BoxFit.cover] so the
///   reel fills the screen (no letterbox / "zoomed out" look).
/// - Landscape video on a portrait viewport: [BoxFit.contain] so the full
///   frame is visible without aggressive side-crop zoom.
BoxFit resolveMomentVideoFit({
  required Size video,
  required Size viewport,
}) {
  if (!_isPositive(video) || !_isPositive(viewport)) {
    return BoxFit.cover;
  }

  final videoAr = video.width / video.height;
  final viewAr = viewport.width / viewport.height;

  final videoIsLandscape = videoAr > 1.05;
  final viewportIsPortrait = viewAr < 0.95;

  if (videoIsLandscape && viewportIsPortrait) {
    return BoxFit.contain;
  }

  return BoxFit.cover;
}

bool _isPositive(Size size) =>
    size.width.isFinite &&
    size.height.isFinite &&
    size.width > 0 &&
    size.height > 0;
