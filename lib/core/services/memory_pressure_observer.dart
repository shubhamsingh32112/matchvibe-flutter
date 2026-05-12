/// Three-step memory-pressure ladder for the global Flutter image cache.
///
/// Background:
/// `WidgetsBindingObserver.didHaveMemoryPressure` fires when the OS warns the
/// process it's running out of memory. Flutter's default reaction is to call
/// `imageCache.clear()` plus `clearLiveImages()`, which is a sledgehammer:
/// every avatar in the feed has to be redownloaded + redecoded on the next
/// rebuild, causing a visible flicker.
///
/// Instead we step down progressively per the migration plan §16:
///   Step 1: halve `maximumSizeBytes` (force LRU eviction of cold textures).
///   Step 2: `imageCache.clear()` if pressure persists for >30s.
///   Step 3: `imageCache.clearLiveImages()` only if pressure STILL persists.
///
/// After 2 minutes without further pressure events we restore the original
/// budget so the user gets back to baseline quality.
///
/// Periodic telemetry: every 30 seconds we ship the current cache footprint
/// (`currentSizeBytes`) to the backend so dashboards can spot regressions
/// without waiting for an OS pressure signal.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'image_render_metrics_reporter.dart';

@visibleForTesting
class MemoryPressureClock {
  const MemoryPressureClock();
  DateTime now() => DateTime.now();
}

class MemoryPressureObserver with WidgetsBindingObserver {
  MemoryPressureObserver({
    @visibleForTesting MemoryPressureClock clock = const MemoryPressureClock(),
  }) : _clock = clock;

  static MemoryPressureObserver? _instance;
  static MemoryPressureObserver get instance =>
      _instance ??= MemoryPressureObserver();

  /// Test seam.
  @visibleForTesting
  static void debugSet(MemoryPressureObserver observer) {
    _instance?.dispose();
    _instance = observer;
  }

  final MemoryPressureClock _clock;

  /// Window inside which repeated pressure events escalate to the next step.
  static const Duration _stepWindow = Duration(seconds: 30);

  /// Idle time before we restore the pre-pressure cache budget.
  static const Duration _restoreDelay = Duration(minutes: 2);

  /// Default budget we restore to (matches main.dart's startup value).
  static const int _defaultMaxBytes = 150 << 20;

  /// Period for shipping cache-size observations.
  static const Duration _statsInterval = Duration(seconds: 30);

  /// Soft cap for individual step-1 evictions — never shrink below 32 MB.
  static const int _minMaxBytes = 32 << 20;

  bool _registered = false;
  int? _stashedMaxBytes;
  int _step = 0;
  DateTime? _lastPressureAt;
  Timer? _restoreTimer;
  Timer? _statsTimer;

  void register() {
    if (_registered) return;
    _registered = true;
    WidgetsBinding.instance.addObserver(this);
    _scheduleStats();
  }

  void dispose() {
    if (!_registered) return;
    _registered = false;
    WidgetsBinding.instance.removeObserver(this);
    _restoreTimer?.cancel();
    _restoreTimer = null;
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  @override
  void didHaveMemoryPressure() {
    _handlePressure();
  }

  /// Visible for testing — direct entry point matching `didHaveMemoryPressure`.
  @visibleForTesting
  void handlePressureForTest() => _handlePressure();

  void _handlePressure() {
    final cache = PaintingBinding.instance.imageCache;
    final now = _clock.now();
    final lastAt = _lastPressureAt;
    final inWindow = lastAt != null && now.difference(lastAt) <= _stepWindow;

    if (!inWindow) {
      _step = 0; // fresh pressure sequence
    }
    _lastPressureAt = now;
    _step = (_step + 1).clamp(1, 3);

    _stashedMaxBytes ??= cache.maximumSizeBytes;

    switch (_step) {
      case 1:
        cache.maximumSizeBytes =
            (cache.maximumSizeBytes ~/ 2).clamp(_minMaxBytes, _defaultMaxBytes);
        _emitStepTelemetry('cache-pressure-1', cache.currentSizeBytes);
        break;
      case 2:
        cache.clear();
        _emitStepTelemetry('cache-pressure-2', cache.currentSizeBytes);
        break;
      case 3:
        cache.clearLiveImages();
        _emitStepTelemetry('cache-pressure-3', cache.currentSizeBytes);
        break;
    }

    _scheduleRestore();
  }

  void _scheduleRestore() {
    _restoreTimer?.cancel();
    _restoreTimer = Timer(_restoreDelay, _restoreBaseline);
  }

  void _restoreBaseline() {
    final cache = PaintingBinding.instance.imageCache;
    final stashed = _stashedMaxBytes ?? _defaultMaxBytes;
    cache.maximumSizeBytes = stashed;
    _step = 0;
    _stashedMaxBytes = null;
    _lastPressureAt = null;
    _emitStepTelemetry('cache-restored', cache.currentSizeBytes);
  }

  void _scheduleStats() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(_statsInterval, (_) => _emitStats());
  }

  void _emitStats() {
    final cache = PaintingBinding.instance.imageCache;
    final bytes = cache.currentSizeBytes;
    if (bytes < 0) return;
    final megabytes = (bytes / (1 << 20)).round().clamp(0, 60000);
    // We piggy-back on the render-latency endpoint by treating MB as the
    // numeric channel and using a dedicated short variant tag. The backend
    // accepts any short tag matching /^[a-z][a-z0-9-]{0,31}$/.
    ImageRenderMetricsReporter.instance.record(
      variant: 'cache-bytes-mb',
      latencyMs: megabytes,
      decoded: true,
    );
  }

  void _emitStepTelemetry(String tag, int currentBytes) {
    if (kDebugMode) {
      final mb = (currentBytes / (1 << 20)).toStringAsFixed(1);
      debugPrint('[MemoryPressureObserver] $tag (currentSizeMB=$mb)');
    }
    final megabytes =
        (currentBytes / (1 << 20)).round().clamp(0, 60000);
    ImageRenderMetricsReporter.instance.record(
      variant: tag,
      latencyMs: megabytes,
      decoded: true,
    );
  }
}
