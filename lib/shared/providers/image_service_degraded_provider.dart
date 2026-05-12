/// Tracks whether the backend image pipeline is currently degraded.
///
/// Source of truth: the `X-Image-Service-Degraded: 1` response header set by
/// the backend when Cloudflare circuit breaker is open, credentials are
/// missing, or the feature flag is off.
///
/// Read-side:
///   - [ImageServiceDegradedBanner] watches this provider and renders a
///     non-blocking banner.
///   - Upload screens (`edit_profile_screen.dart`) listen for the healthy
///     transition to auto-retry pending uploads.
///
/// Write-side: only the API client interceptor calls [markDegraded] and
/// [markHealthy]. Manual writes are gated behind `@visibleForTesting`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ImageServiceDegradedState {
  const ImageServiceDegradedState({
    required this.isDegraded,
    required this.lastChangeAtMs,
  });

  /// True when the most recent observation said degraded.
  final bool isDegraded;

  /// Epoch ms of the last transition — used to debounce the banner so it
  /// doesn't flash off and on too quickly.
  final int lastChangeAtMs;

  static const ImageServiceDegradedState healthy = ImageServiceDegradedState(
    isDegraded: false,
    lastChangeAtMs: 0,
  );

  ImageServiceDegradedState copyWith({
    bool? isDegraded,
    int? lastChangeAtMs,
  }) {
    return ImageServiceDegradedState(
      isDegraded: isDegraded ?? this.isDegraded,
      lastChangeAtMs: lastChangeAtMs ?? this.lastChangeAtMs,
    );
  }
}

class ImageServiceDegradedNotifier
    extends StateNotifier<ImageServiceDegradedState> {
  ImageServiceDegradedNotifier() : super(ImageServiceDegradedState.healthy);

  /// Called from the Dio interceptor when a response surfaces
  /// `X-Image-Service-Degraded: 1`. Idempotent.
  void markDegraded() {
    if (state.isDegraded) return;
    state = state.copyWith(
      isDegraded: true,
      lastChangeAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Called when a "health-revealing" response succeeds — i.e. a request to
  /// a path that would have set the degraded header had Cloudflare been
  /// unhealthy. Idempotent.
  void markHealthy() {
    if (!state.isDegraded) return;
    state = state.copyWith(
      isDegraded: false,
      lastChangeAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @visibleForTesting
  void debugSet({required bool degraded}) {
    state = state.copyWith(
      isDegraded: degraded,
      lastChangeAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Global Riverpod provider.
final imageServiceDegradedProvider =
    StateNotifierProvider<ImageServiceDegradedNotifier,
        ImageServiceDegradedState>(
  (ref) => ImageServiceDegradedNotifier(),
);

/// Set of API paths whose 2xx responses prove the image pipeline is healthy.
/// Anything *not* on this list is ambiguous: a 200 from `/user/list` says
/// nothing about Cloudflare, so we do not clear the degraded flag on it.
///
/// Refinement 5: ONLY clear on these well-defined upload/commit success
/// paths. `PUT /user/profile` is excluded because a profile-only edit (no
/// avatarUploadSessionId in payload) does not actually exercise Cloudflare.
const Set<String> kImageServiceHealthPaths = {
  '/images/direct-upload',
  '/images/presets',
  '/images/health',
  '/creator/profile/gallery/commit',
};

/// Path-suffix matchers used in addition to [kImageServiceHealthPaths].
const List<String> kImageServiceHealthPathSuffixes = <String>[];

/// Returns true if a successful response on [path] should mark the pipeline
/// healthy.
bool isImageHealthRevealingPath(String path) {
  final clean = path.split('?').first;
  if (kImageServiceHealthPaths.contains(clean)) return true;
  for (final suffix in kImageServiceHealthPathSuffixes) {
    if (clean.endsWith(suffix)) return true;
  }
  return false;
}
