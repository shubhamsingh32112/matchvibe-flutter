/// Three tuned `CacheManager` instances per §7.3 of the Cloudflare-images
/// migration plan.
///
///   - [avatarCacheManager]  : 365d stalePeriod, 2000 entries (hot, sticky)
///   - [feedCacheManager]    : 90d  stalePeriod, 500  entries (warm churn)
///   - [galleryCacheManager] : 365d stalePeriod, 300  entries (medium)
///
/// All managers persist to disk via the default flutter_cache_manager backend.
/// They use a custom [HttpFileService] that advertises AVIF/WebP support to
/// Cloudflare and retries transient failures (see [_AvifAwareHttpFileService]).
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

/// Hot path: chat / recent / call / feed-card avatars.
/// Aggressive retention so they persist across cold restarts.
final CacheManager avatarCacheManager = CacheManager(
  Config(
    'matchvibe_avatars',
    stalePeriod: const Duration(days: 365),
    maxNrOfCacheObjects: 2000,
    fileService: _avifAwareHttpFileService,
  ),
);

/// Feed-tile thumbnails — rotates faster as user scrolls infinite list.
final CacheManager feedCacheManager = CacheManager(
  Config(
    'matchvibe_feed',
    stalePeriod: const Duration(days: 90),
    maxNrOfCacheObjects: 500,
    fileService: _avifAwareHttpFileService,
  ),
);

/// Gallery thumbs / medium / xl — moderate retention.
final CacheManager galleryCacheManager = CacheManager(
  Config(
    'matchvibe_gallery',
    stalePeriod: const Duration(days: 365),
    maxNrOfCacheObjects: 300,
    fileService: _avifAwareHttpFileService,
  ),
);

/// Shared singleton — one HTTP client for the whole image pipeline.
final HttpFileService _avifAwareHttpFileService = _AvifAwareHttpFileService();

/// Custom `HttpFileService` that:
///   1. Sets `Accept: image/avif,image/webp,image/*;q=0.8` on every GET so
///      Cloudflare can pick the smallest format the device supports.
///   2. Retries transient failures (SocketException, 5xx) with exponential
///      backoff up to 2 retries. 404s fail fast (no point retrying a missing
///      asset).
class _AvifAwareHttpFileService extends HttpFileService {
  _AvifAwareHttpFileService() : super(httpClient: http.Client());

  static const Map<String, String> _acceptHeaders = {
    'Accept': 'image/avif,image/webp,image/*;q=0.8',
  };

  static const int _maxRetries = 2;
  static const Duration _baseBackoff = Duration(milliseconds: 400);

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final merged = <String, String>{
      ..._acceptHeaders,
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

    throw lastError ?? Exception('Image fetch failed: $url');
  }
}
