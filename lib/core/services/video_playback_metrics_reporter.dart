import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../api/api_client.dart';
import 'sentry_service.dart';

@immutable
class VideoPlaybackSample {
  const VideoPlaybackSample({
    required this.event,
    required this.context,
    required this.valueMs,
    required this.weight,
    this.completed,
    this.watchedPct,
    this.httpStatus,
    this.reason,
    this.phase,
    this.errorClass,
    required this.sampledAt,
  });

  final String event;
  final String context;
  final int valueMs;
  final int weight;
  final bool? completed;
  final int? watchedPct;
  final int? httpStatus;
  final String? reason;
  final String? phase;
  final String? errorClass;
  final int sampledAt;

  Map<String, Object?> toJson() => {
        'event': event,
        'context': context,
        'valueMs': valueMs,
        'weight': weight,
        if (completed != null) 'completed': completed,
        if (watchedPct != null) 'watchedPct': watchedPct,
        if (httpStatus != null) 'httpStatus': httpStatus,
        if (reason != null) 'reason': reason,
        if (phase != null) 'phase': phase,
        if (errorClass != null) 'errorClass': errorClass,
        'sampledAt': sampledAt,
      };
}

class VideoPlaybackMetricsReporter {
  VideoPlaybackMetricsReporter._({
    ApiClient? apiClient,
    math.Random? random,
    bool? enabled,
    bool skipPerfSampling = false,
    Future<void> Function(String path, Map<String, dynamic> data)? postOverride,
  })  : _apiClient = apiClient,
        _random = random ?? math.Random(),
        _enabled = enabled ?? _resolveEnabledDefault(),
        _skipPerfSampling = skipPerfSampling,
        _postOverride = postOverride;

  final bool _skipPerfSampling;
  final Future<void> Function(String path, Map<String, dynamic> data)? _postOverride;

  @visibleForTesting
  factory VideoPlaybackMetricsReporter.forTest({
    ApiClient? apiClient,
    math.Random? random,
    bool enabled = true,
    bool skipPerfSampling = false,
    Future<void> Function(String path, Map<String, dynamic> data)? postOverride,
  }) {
    return VideoPlaybackMetricsReporter._(
      apiClient: apiClient,
      random: random,
      enabled: enabled,
      skipPerfSampling: skipPerfSampling,
      postOverride: postOverride,
    );
  }

  static VideoPlaybackMetricsReporter _instance =
      VideoPlaybackMetricsReporter._();

  static VideoPlaybackMetricsReporter get instance => _instance;

  @visibleForTesting
  static void debugSet(VideoPlaybackMetricsReporter reporter) {
    _instance = reporter;
  }

  @visibleForTesting
  int get bufferLength => _buffer.length;

  static bool _resolveEnabledDefault() {
    const fromDefine = String.fromEnvironment(
      'MOMENTS_VIDEO_PLAYBACK_METRICS',
      defaultValue: '',
    );
    if (fromDefine == 'false') return false;
    if (fromDefine == 'true') return true;
    try {
      final fromEnv = (dotenv.env['MOMENTS_VIDEO_PLAYBACK_METRICS'] ?? '').trim();
      if (fromEnv == 'false') return false;
      if (fromEnv == 'true') return true;
    } catch (_) {}
    return true;
  }

  final ApiClient? _apiClient;
  final math.Random _random;
  bool _enabled;

  static const int _maxBufferSize = 40;
  static const Duration _flushInterval = Duration(seconds: 30);
  static const double _sampleRate = 0.10;
  static const int _sampleWeight = 10;
  static const int _errorSampleWeight = 1;

  static const Set<String> _alwaysSampleEvents = {
    'player_error',
    'token_refresh_fail',
  };

  final List<VideoPlaybackSample> _buffer = [];
  Timer? _flushTimer;
  bool _started = false;

  bool get enabled => _enabled;

  void _ensureStarted() {
    if (_started) return;
    _started = true;
    _flushTimer = Timer.periodic(_flushInterval, (_) => unawaited(flush()));
  }

  bool _shouldSample(String event) {
    if (!_enabled) return false;
    if (_alwaysSampleEvents.contains(event)) return true;
    if (_skipPerfSampling) return false;
    return _random.nextDouble() <= _sampleRate;
  }

  int _weightFor(String event) =>
      _alwaysSampleEvents.contains(event) ? _errorSampleWeight : _sampleWeight;

  void record({
    required String event,
    required String context,
    int valueMs = 0,
    bool? completed,
    int? watchedPct,
    int? httpStatus,
    String? reason,
    String? phase,
    String? errorClass,
  }) {
    if (!_shouldSample(event)) return;
    _ensureStarted();
    _buffer.add(
      VideoPlaybackSample(
        event: event,
        context: context,
        valueMs: valueMs,
        weight: _weightFor(event),
        completed: completed,
        watchedPct: watchedPct,
        httpStatus: httpStatus,
        reason: reason,
        phase: phase,
        errorClass: errorClass,
        sampledAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (_alwaysSampleEvents.contains(event)) {
      _reportSentryBreadcrumb(
        event: event,
        context: context,
        phase: phase,
        errorClass: errorClass,
        httpStatus: httpStatus,
        reason: reason,
      );
    }
    if (_buffer.length >= _maxBufferSize) {
      unawaited(flush());
    }
  }

  void _reportSentryBreadcrumb({
    required String event,
    required String context,
    String? phase,
    String? errorClass,
    int? httpStatus,
    String? reason,
  }) {
    SentryService.addThrottledBreadcrumb(
      category: 'moments_hls',
      message: '$event:$context',
      level: SentryLevel.warning,
      data: {
        'feature': 'moments_hls',
        'event': event,
        'context': context,
        if (phase != null) 'phase': phase,
        if (errorClass != null) 'error_class': errorClass,
        if (httpStatus != null) 'http_status': httpStatus,
        if (reason != null) 'reason': reason,
      },
    );
  }

  void flushOnBackground() => unawaited(flush());

  Future<void> flush() async {
    if (_buffer.isEmpty) return;
    final batch = List<VideoPlaybackSample>.from(_buffer);
    _buffer.clear();
    try {
      final payload = {
        'samples': batch.map((s) => s.toJson()).toList(),
      };
      if (_postOverride != null) {
        await _postOverride!('/metrics/video-playback', payload);
      } else {
        await (_apiClient ?? ApiClient()).post(
          '/metrics/video-playback',
          data: payload,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[video-playback-metrics] flush failed (dropping batch): $e');
      }
    }
  }

  @visibleForTesting
  void debugClear() {
    _buffer.clear();
  }
}
