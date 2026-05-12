/// Buffer + flush sink for client-side image-render latency telemetry.
///
/// Why a dedicated reporter:
///   - We want a single timer that batches samples to keep cost low.
///   - Hot widgets (AppNetworkImage, CachedNetworkImage callers) push samples
///     without awaiting network — telemetry MUST NEVER block render.
///   - Sampling is *variant-weighted*: avatars are noisy, gallery loads are
///     rare. Weighting at sample time lets us aggregate fairly without
///     shipping every event.
///
/// Sampling rates (1 = always, 0.05 = 5% of events ship):
///   * avatarXs / avatarSm / avatarMd / feedTile     : 0.05  → weight 20
///   * callPhoto / callBg                            : 0.10  → weight 10
///   * galleryThumb / galleryMd / galleryXl          : 0.25  → weight 4
///   * default                                       : 0.10  → weight 10
///
/// Flush behaviour:
///   - Buffer is drained every 30 seconds OR when ≥40 samples accumulate.
///   - Send is fire-and-forget; failures drop the batch (NEVER retry — we'd
///     rather lose a batch than amplify a degraded backend with retries).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';

/// Public sample record (per render event).
@immutable
class ImageRenderSample {
  const ImageRenderSample({
    required this.variant,
    required this.latencyMs,
    required this.decoded,
    required this.weight,
    required this.sampledAt,
  });

  final String variant;
  final int latencyMs;
  final bool decoded;
  final int weight;
  final int sampledAt;

  Map<String, Object?> toJson() => {
        'variant': variant,
        'latencyMs': latencyMs,
        'decoded': decoded,
        'weight': weight,
        'sampledAt': sampledAt,
      };
}

/// Singleton sink. Test code can swap `instance` via the [debugSet] hook.
class ImageRenderMetricsReporter {
  ImageRenderMetricsReporter._({ApiClient? apiClient, math.Random? random})
      : _apiClient = apiClient ?? ApiClient(),
        _random = random ?? math.Random();

  static ImageRenderMetricsReporter _instance =
      ImageRenderMetricsReporter._();

  static ImageRenderMetricsReporter get instance => _instance;

  /// Test-only override.
  @visibleForTesting
  static void debugSet(ImageRenderMetricsReporter reporter) {
    _instance = reporter;
  }

  final ApiClient _apiClient;
  final math.Random _random;

  static const int _maxBufferSize = 40;
  static const Duration _flushInterval = Duration(seconds: 30);
  static const int _maxLatencyMs = 60000;

  /// Sample rate table — keep in sync with backend `VARIANT_RE` in
  /// `image-render-metrics.controller.ts` (`/^[a-z][a-zA-Z0-9]{0,31}$/` —
  /// camelCase only, no hyphens). Memory/cache tags are always shipped.
  static const Map<String, double> _sampleRates = {
    'avatarXs': 0.05,
    'avatarSm': 0.05,
    'avatarMd': 0.05,
    'feedTile': 0.05,
    'callPhoto': 0.10,
    'callBg': 0.10,
    'galleryThumb': 0.25,
    'galleryMd': 0.25,
    'galleryXl': 0.25,
    // Memory / cache telemetry — always ship (must match backend variant rules).
    'cacheBytesMb': 1.0,
    'cachePressure1': 1.0,
    'cachePressure2': 1.0,
    'cachePressure3': 1.0,
    'cacheRestored': 1.0,
  };
  static const double _defaultRate = 0.10;

  final List<ImageRenderSample> _buffer = <ImageRenderSample>[];
  Timer? _flushTimer;
  bool _isFlushing = false;
  bool _disabled = false;

  /// Push a render-timing observation. Returns immediately.
  /// Variant-weighted random sampling decides whether to keep the sample.
  void record({
    required String variant,
    required int latencyMs,
    required bool decoded,
  }) {
    if (_disabled) return;
    if (variant.isEmpty) return;
    if (latencyMs < 0 || latencyMs > _maxLatencyMs) return;

    final rate = _sampleRates[variant] ?? _defaultRate;
    if (rate <= 0.0) return;
    if (rate < 1.0 && _random.nextDouble() >= rate) return;
    final weight = (1.0 / rate).round().clamp(1, 10000);

    _buffer.add(ImageRenderSample(
      variant: variant,
      latencyMs: latencyMs,
      decoded: decoded,
      weight: weight,
      sampledAt: DateTime.now().millisecondsSinceEpoch,
    ));

    if (_buffer.length >= _maxBufferSize) {
      unawaited(_flush());
    } else {
      _ensureTimer();
    }
  }

  /// Force a flush (e.g. on app backgrounding). Best-effort.
  Future<void> flush() => _flush();

  /// Stop the reporter (tests / app-shutdown).
  void disable() {
    _disabled = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    _buffer.clear();
  }

  void _ensureTimer() {
    if (_flushTimer != null) return;
    _flushTimer = Timer(_flushInterval, () {
      _flushTimer = null;
      unawaited(_flush());
    });
  }

  Future<void> _flush() async {
    if (_isFlushing) return;
    if (_buffer.isEmpty) return;
    _isFlushing = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    final batch = List<ImageRenderSample>.unmodifiable(_buffer);
    _buffer.clear();
    try {
      await _apiClient.post(
        '/metrics/image-render',
        data: {
          'samples': batch.map((s) => s.toJson()).toList(growable: false),
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[image-render-metrics] flush failed (dropping batch): $e');
      }
      // Drop intentionally; never retry telemetry to avoid hammering a
      // degraded backend.
    } finally {
      _isFlushing = false;
    }
  }
}
