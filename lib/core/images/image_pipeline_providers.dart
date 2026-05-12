/// Global state for the Cloudflare-images pipeline.
///
/// Per plan §7.1b and §6.11:
///   - [useCloudflareImagesProvider]    : feature flag — when false, legacy
///                                        Firebase URL paths are still honored
///                                        by adapters (avatar/gallery fromJson).
///   - [imageServiceDegradedProvider]   : flipped to `true` when the backend
///                                        responds with `X-Image-Service-
///                                        Degraded: 1` (Cloudflare circuit
///                                        breaker is open). Screens watch this
///                                        and surface a non-blocking banner.
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<bool> useCloudflareImagesProvider = Provider<bool>((ref) {
  final raw = (dotenv.env['USE_CLOUDFLARE_IMAGES'] ?? '').trim().toLowerCase();
  return raw == 'true' || raw == '1' || raw == 'yes';
});

class ImageServiceDegradedNotifier extends StateNotifier<bool> {
  ImageServiceDegradedNotifier() : super(false);

  void markDegraded() {
    if (!state) state = true;
  }

  void markHealthy() {
    if (state) state = false;
  }
}

final StateNotifierProvider<ImageServiceDegradedNotifier, bool>
    imageServiceDegradedProvider =
    StateNotifierProvider<ImageServiceDegradedNotifier, bool>(
  (ref) => ImageServiceDegradedNotifier(),
);
