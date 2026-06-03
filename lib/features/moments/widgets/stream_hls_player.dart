import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/services/video_playback_metrics_reporter.dart';
import '../models/playback_refresh_models.dart';
import '../services/moments_api_service.dart';

/// HLS player with strict local lifecycle — never store controller in providers.
class StreamHlsPlayer extends StatefulWidget {
  const StreamHlsPlayer({
    super.key,
    required this.playbackUrl,
    this.momentId,
    this.storyId,
    this.playbackContext = 'reels',
    this.autoplay = true,
    this.loop = true,
    this.muted = true,
    this.enableTokenRefresh = true,
    this.expiresAtMs,
    this.initDelay = Duration.zero,
  });

  final String? momentId;
  final String? storyId;
  final String playbackContext;
  final String playbackUrl;
  final bool autoplay;
  final bool loop;
  final bool muted;
  final bool enableTokenRefresh;
  final int? expiresAtMs;
  final Duration initDelay;

  @override
  State<StreamHlsPlayer> createState() => _StreamHlsPlayerState();
}

class _StreamHlsPlayerState extends State<StreamHlsPlayer> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Timer? _refreshTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  final _api = MomentsApiService();
  final _storiesApi = StoriesApiService();
  final _metrics = VideoPlaybackMetricsReporter.instance;

  String _currentUrl = '';
  int? _tokenExpiresAtMs;
  int _generation = 0;
  bool _disposed = false;
  bool _appPaused = false;
  bool _wasPlayingBeforePause = false;
  bool _offline = false;
  bool _refreshInFlight = false;
  bool _swapInFlight = false;
  bool _errorRecoveryScheduled = false;

  Duration _bufferingAccumulated = Duration.zero;
  DateTime? _bufferingStartedAt;
  int _stallCount = 0;
  DateTime? _initStartedAt;
  bool _startupRecorded = false;
  int _runtimeErrorRetries = 0;

  static const _refreshLeadMs = 15 * 60 * 1000;
  static const _maxRuntimeRetries = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUrl = widget.playbackUrl;
    _tokenExpiresAtMs = widget.expiresAtMs;
    if (widget.initDelay > Duration.zero) {
      Future<void>.delayed(widget.initDelay, () {
        if (!_disposed) _initPlayer(_currentUrl);
      });
    } else {
      _initPlayer(_currentUrl);
    }
    _scheduleRefreshTimer();
    _connectivitySub = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  @override
  void didUpdateWidget(covariant StreamHlsPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playbackUrl != widget.playbackUrl) {
      _currentUrl = widget.playbackUrl;
      _tokenExpiresAtMs = widget.expiresAtMs;
      unawaited(_swapController(_currentUrl));
    } else if (oldWidget.expiresAtMs != widget.expiresAtMs) {
      _tokenExpiresAtMs = widget.expiresAtMs;
      _scheduleRefreshTimer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _appPaused = true;
      final c = _controller;
      if (c != null && c.value.isInitialized) {
        _wasPlayingBeforePause = c.value.isPlaying;
        c.pause();
      }
      if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
        _metrics.flushOnBackground();
      }
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _appPaused = false;
      _maybeRefreshNearExpiry(force: true);
      final c = _controller;
      if (c != null && c.value.isInitialized && (_wasPlayingBeforePause || widget.autoplay)) {
        unawaited(c.play());
      }
    }
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final offline = results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none);
    final wasOffline = _offline;
    _offline = offline;
    if (wasOffline && !offline && !_disposed) {
      final c = _controller;
      if (c == null || !c.value.isInitialized || c.value.hasError) {
        await _swapController(_currentUrl);
      }
    }
  }

  void _scheduleRefreshTimer() {
    _refreshTimer?.cancel();
    if (!widget.enableTokenRefresh) return;
    if (widget.momentId == null && widget.storyId == null) return;

    final expiresAt = _tokenExpiresAtMs;
    Duration interval;
    if (expiresAt != null) {
      final refreshAt = expiresAt - _refreshLeadMs;
      final delayMs = refreshAt - DateTime.now().millisecondsSinceEpoch;
      interval = Duration(milliseconds: delayMs.clamp(60 * 1000, 45 * 60 * 1000));
    } else {
      interval = const Duration(minutes: 45);
    }

    _refreshTimer = Timer(interval, () async {
      await _refreshSilently();
      if (!_disposed) _scheduleRefreshTimer();
    });
  }

  void _maybeRefreshNearExpiry({bool force = false}) {
    final expiresAt = _tokenExpiresAtMs;
    if (expiresAt == null) return;
    final msUntilExpiry = expiresAt - DateTime.now().millisecondsSinceEpoch;
    if (force || msUntilExpiry <= _refreshLeadMs) {
      unawaited(_refreshSilently());
    }
  }

  Future<void> _initPlayer(String url) async {
    _initStartedAt = DateTime.now();
    await _swapController(url);
  }

  void _attachListener(VideoPlayerController controller, int gen) {
    controller.addListener(() {
      if (_disposed || gen != _generation) return;
      _handleControllerUpdate(controller);
    });
  }

  void _handleControllerUpdate(VideoPlayerController controller) {
    final value = controller.value;

    if (!value.hasError && value.isInitialized) {
      _errorRecoveryScheduled = false;
    }

    if (!_startupRecorded && value.isInitialized) {
      _startupRecorded = true;
      final started = _initStartedAt;
      if (started != null) {
        final ms = DateTime.now().difference(started).inMilliseconds;
        _metrics.record(
          event: 'startup',
          context: widget.playbackContext,
          valueMs: ms,
        );
      }
    }

    if (value.isBuffering) {
      _bufferingStartedAt ??= DateTime.now();
    } else if (_bufferingStartedAt != null) {
      _bufferingAccumulated += DateTime.now().difference(_bufferingStartedAt!);
      _bufferingStartedAt = null;
      _stallCount += 1;
    }

    if (!value.hasError) return;
    if (_errorRecoveryScheduled || _runtimeErrorRetries >= _maxRuntimeRetries) return;

    _errorRecoveryScheduled = true;
    _runtimeErrorRetries += 1;
    _metrics.record(
      event: 'player_error',
      context: widget.playbackContext,
      phase: 'play',
      errorClass: value.errorDescription ?? 'runtime',
    );
    if (widget.enableTokenRefresh && !_offline) {
      unawaited(_refreshSilently());
    } else if (!_offline) {
      unawaited(_swapController(_currentUrl));
    }
  }

  Future<void> _swapController(String url) async {
    if (_disposed || _swapInFlight) return;
    _swapInFlight = true;
    final gen = ++_generation;
    final old = _controller;

    Duration? savedPosition;
    var wasPlaying = widget.autoplay;
    if (old != null && old.value.isInitialized) {
      savedPosition = old.value.position;
      wasPlaying = old.value.isPlaying;
    }

    final next = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      if (_disposed || gen != _generation) {
        await next.dispose();
        return;
      }
      _controller = next;

      await next.initialize();
      if (_disposed || gen != _generation) {
        await next.dispose();
        if (_controller == next) _controller = null;
        return;
      }
      await next.setLooping(widget.loop);
      await next.setVolume(widget.muted ? 0 : 1);
      if (savedPosition != null && savedPosition > Duration.zero) {
        final dur = next.value.duration;
        if (dur > Duration.zero && savedPosition < dur) {
          await next.seekTo(savedPosition);
        }
      }
      if (!_appPaused && (wasPlaying || widget.autoplay)) {
        await next.play();
      }
      _attachListener(next, gen);
      _errorRecoveryScheduled = false;
      if (mounted) setState(() {});
    } catch (e) {
      _metrics.record(
        event: 'player_error',
        context: widget.playbackContext,
        phase: 'init',
        errorClass: e.runtimeType.toString(),
      );
      if (widget.enableTokenRefresh && !_offline) {
        await _refreshSilently();
      }
    } finally {
      if (old != null && old != _controller) {
        await old.dispose();
      }
      _swapInFlight = false;
    }
  }

  Future<void> _refreshSilently() async {
    if (_refreshInFlight || _offline) return;
    if (!widget.enableTokenRefresh) return;

    final momentId = widget.momentId;
    final storyId = widget.storyId;
    if (momentId == null && storyId == null) return;

    _refreshInFlight = true;
    try {
      final PlaybackRefreshResult result;
      if (momentId != null) {
        result = await _api.refreshPlayback(momentId);
      } else {
        result = await _storiesApi.refreshPlayback(storyId!);
      }
      if (result.playbackUrl.isNotEmpty && result.playbackUrl != _currentUrl) {
        _currentUrl = result.playbackUrl;
        _tokenExpiresAtMs = result.expiresAtMs;
        await _swapController(result.playbackUrl);
      } else if (result.expiresAtMs > 0) {
        _tokenExpiresAtMs = result.expiresAtMs;
        _scheduleRefreshTimer();
      }
    } on PlaybackRefreshException catch (e) {
      _metrics.record(
        event: 'token_refresh_fail',
        context: widget.playbackContext,
        httpStatus: e.statusCode,
        reason: e.code ?? e.message,
      );
    } catch (e) {
      _metrics.record(
        event: 'token_refresh_fail',
        context: widget.playbackContext,
        reason: e.runtimeType.toString(),
      );
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<void> _recordSessionMetrics() async {
    if (_bufferingStartedAt != null) {
      _bufferingAccumulated += DateTime.now().difference(_bufferingStartedAt!);
      _bufferingStartedAt = null;
    }
    if (_bufferingAccumulated > Duration.zero || _stallCount > 0) {
      _metrics.record(
        event: 'buffering',
        context: widget.playbackContext,
        valueMs: _bufferingAccumulated.inMilliseconds,
        reason: _stallCount > 0 ? 'stalls:$_stallCount' : null,
      );
    }

    final c = _controller;
    if (c != null && c.value.isInitialized && c.value.duration > Duration.zero) {
      final watchedPct =
          (c.value.position.inMilliseconds / c.value.duration.inMilliseconds * 100)
              .round()
              .clamp(0, 100);
      final completed = watchedPct >= 90 ||
          c.value.position >= c.value.duration - const Duration(milliseconds: 500);
      if (watchedPct >= 10) {
        _metrics.record(
          event: 'completion',
          context: widget.playbackContext,
          completed: completed,
          watchedPct: watchedPct,
        );
        if (completed) {
          final momentId = widget.momentId;
          final storyId = widget.storyId;
          if (momentId != null) {
            unawaited(_api.completeMoment(momentId, watchedPct: watchedPct, completed: completed));
          } else if (storyId != null) {
            unawaited(_storiesApi.completeStory(storyId, watchedPct: watchedPct, completed: completed));
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _refreshTimer?.cancel();
    _connectivitySub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_recordSessionMetrics());
    _metrics.flushOnBackground();
    final c = _controller;
    _controller = null;
    unawaited(_disposeController(c));
    super.dispose();
  }

  Future<void> _disposeController(VideoPlayerController? c) async {
    if (c == null) return;
    try {
      await c.dispose();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: c.value.size.width,
        height: c.value.size.height,
        child: VideoPlayer(c),
      ),
    );
  }
}
