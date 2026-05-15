/// Three tuned cache managers per §7.3 of the Cloudflare-images migration plan.
///
///   - [avatarCacheManager]  : 365d stalePeriod, 2000 entries (hot, sticky)
///   - [feedCacheManager]    : 90d  stalePeriod, 500  entries (warm churn)
///   - [galleryCacheManager] : 365d stalePeriod, 300  entries (medium)
///
/// Each extends [CacheManager] with [ImageCacheManager] so [CachedNetworkImage]
/// can use memCacheWidth/Height (required by [AppNetworkImage]).
///
/// All managers persist to disk via the default flutter_cache_manager backend.
/// They use a custom [HttpFileService] that negotiates WebP/AVIF with
/// Cloudflare and retries transient failures (see [_CloudflareImageFileService]).
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

/// [CacheManager] + [ImageCacheManager] for resized decode via memCacheWidth/Height.
class _CloudflareImageCacheManager extends CacheManager with ImageCacheManager {
  _CloudflareImageCacheManager(super.config);
}

/// Hot path: chat / recent / call / feed-card avatars.
/// Aggressive retention so they persist across cold restarts.
final CacheManager avatarCacheManager = _CloudflareImageCacheManager(
  Config(
    'matchvibe_avatars_v2',
    stalePeriod: const Duration(days: 365),
    maxNrOfCacheObjects: 2000,
    fileService: _cloudflareImageFileService,
  ),
);

/// Feed-tile thumbnails — rotates faster as user scrolls infinite list.
final CacheManager feedCacheManager = _CloudflareImageCacheManager(
  Config(
    'matchvibe_feed_v2',
    stalePeriod: const Duration(days: 90),
    maxNrOfCacheObjects: 500,
    fileService: _cloudflareImageFileService,
  ),
);

/// Gallery thumbs / medium / xl — moderate retention.
final CacheManager galleryCacheManager = _CloudflareImageCacheManager(
  Config(
    'matchvibe_gallery_v2',
    stalePeriod: const Duration(days: 365),
    maxNrOfCacheObjects: 300,
    fileService: _cloudflareImageFileService,
  ),
);

/// Shared singleton — one HTTP client for the whole image pipeline.
final HttpFileService _cloudflareImageFileService = _CloudflareImageFileService();

/// Accept header for Cloudflare Images format negotiation.
///
/// Android's Flutter image decoder often cannot decode AVIF even when the
/// bytes download successfully — request WebP/JPEG first on Android only.
Map<String, String> cloudflareImageAcceptHeaders() {
  if (!kIsWeb && Platform.isAndroid) {
    return const {'Accept': 'image/webp,image/jpeg,image/*;q=0.8'};
  }
  return const {'Accept': 'image/avif,image/webp,image/*;q=0.8'};
}

/// Custom `HttpFileService` that:
///   1. Sets platform-aware `Accept` so Cloudflare serves a decodable format.
///   2. Retries transient failures (SocketException, 5xx) with exponential
///      backoff up to 2 retries. 404s fail fast (no point retrying a missing
///      asset).
class _CloudflareImageFileService extends HttpFileService {
  _CloudflareImageFileService() : super(httpClient: http.Client());

  static const int _maxRetries = 2;
  static const Duration _baseBackoff = Duration(milliseconds: 400);

  final Set<String> _loggedFailures = <String>{};

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final merged = <String, String>{
      ...cloudflareImageAcceptHeaders(),
      if (headers != null) ...headers,
    };

    Object? lastError;
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await super.get(url, headers: merged);
        if (response.statusCode >= 500 && response.statusCode < 600) {
          lastError = HttpException(
            'Upstream ${response.statusCode} for $url',
          );
        } else {
          if (kDebugMode && response.statusCode == 404 && _loggedFailures.add(url)) {
            debugPrint(
              '[CloudflareImageFileService] 404 for $url '
              '(check account hash, variant name, or imageId)',
            );
          }
          return response;
        }
      } on SocketException catch (e) {
        lastError = e;
      } on HttpException catch (e) {
        lastError = e;
      } on TimeoutException catch (e) {
        lastError = e;
      }

      if (attempt < _maxRetries) {
        final delayMs =
            (_baseBackoff.inMilliseconds * math.pow(2, attempt)).toInt();
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }

    if (kDebugMode && _loggedFailures.add('err:$url')) {
      debugPrint(
        '[CloudflareImageFileService] fetch failed for $url: $lastError',
      );
    }
    throw lastError ?? Exception('Image fetch failed: $url');
  }
}
