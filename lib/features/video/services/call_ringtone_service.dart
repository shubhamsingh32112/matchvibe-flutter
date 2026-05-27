import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:just_audio/just_audio.dart';

enum _CallToneMode { outgoing, incoming }

/// Plays lightweight repeating call tones for outgoing/incoming call states.
///
/// Incoming calls use a custom ringtone from Firebase Storage (with fallbacks).
/// Outgoing calls continue to use lightweight system alert beeps.
class CallRingtoneService {
  CallRingtoneService._();

  static const String _incomingRingtoneStoragePath =
      'ringtone/incoming_creator.mp3';
  static const String _incomingRingtoneAssetPath =
      'lib/assets/ringtone/universfield-ringtone-032-480574.mp3';

  static Timer? _timer;
  static AudioPlayer? _incomingPlayer;
  static _CallToneMode? _activeMode;
  static String? _cachedIncomingRingtoneUrl;
  static int _incomingSessionId = 0;

  static void startOutgoingTone() {
    _start(
      mode: _CallToneMode.outgoing,
      interval: const Duration(milliseconds: 1700),
    );
  }

  static void startIncomingRingtone() {
    if (_activeMode == _CallToneMode.incoming) return;
    final sessionId = ++_incomingSessionId;
    unawaited(_startIncomingRingtoneInternal(sessionId));
  }

  static void stop() {
    _incomingSessionId++;
    _stopActivePlaybackOnly();
    debugPrint('🔕 [CALL TONE] Stopped');
  }

  static void _start({
    required _CallToneMode mode,
    required Duration interval,
  }) {
    // Avoid restarting when the same mode is already active.
    if (_activeMode == mode && _timer != null) return;

    stop();
    _activeMode = mode;

    // Play immediately, then continue periodically.
    _playAlert();
    _timer = Timer.periodic(interval, (_) => _playAlert());
    debugPrint('🔔 [CALL TONE] Started (${mode.name})');
  }

  static Future<void> _startIncomingRingtoneInternal(int sessionId) async {
    if (!_isIncomingSessionActive(sessionId)) return;
    _stopActivePlaybackOnly();
    if (!_isIncomingSessionActive(sessionId)) return;
    _activeMode = _CallToneMode.incoming;

    // Immediate feedback so the user hears something right away.
    _playAlert();

    // Start with bundled asset ringtone (fast, offline).
    var bundledStarted = false;
    try {
      if (!_isIncomingSessionActive(sessionId)) return;
      _incomingPlayer ??= AudioPlayer();
      await _incomingPlayer!.setLoopMode(LoopMode.one);
      if (!_isIncomingSessionActive(sessionId)) return;
      await _incomingPlayer!.setAsset(_incomingRingtoneAssetPath);
      if (!_isIncomingSessionActive(sessionId)) return;
      await _incomingPlayer!.play();
      debugPrint('🔔 [CALL TONE] Started (incoming bundled ringtone)');
      bundledStarted = true;
    } on PlayerInterruptedException {
      debugPrint('🔕 [CALL TONE] Bundled ringtone interrupted (expected)');
    } catch (error) {
      debugPrint(
        '⚠️ [CALL TONE] Asset ringtone failed, will try URL/fallback: $error',
      );
    }

    // Best-effort upgrade to remote URL ringtone (do not block ring start).
    unawaited(() async {
      if (!_isIncomingSessionActive(sessionId)) return;
      try {
        _incomingPlayer ??= AudioPlayer();
        await _incomingPlayer!.setLoopMode(LoopMode.one);
        if (!_isIncomingSessionActive(sessionId)) return;
        final ringtoneUrl = await _resolveIncomingRingtoneUrl();
        if (!_isIncomingSessionActive(sessionId)) return;
        await _incomingPlayer!.setUrl(ringtoneUrl);
        if (!_isIncomingSessionActive(sessionId)) return;
        await _incomingPlayer!.play();
        debugPrint('🔔 [CALL TONE] Upgraded to incoming custom ringtone URL');
      } on PlayerInterruptedException {
        // Expected when stop() races with URL upgrade.
      } catch (_) {
        // Keep bundled ringtone if playing; otherwise fallback timer below.
      }
    }());

    // Bundled ringtone is already active; no need to run another start path.
    if (bundledStarted) return;

    try {
      if (!_isIncomingSessionActive(sessionId)) return;
      _incomingPlayer ??= AudioPlayer();
      await _incomingPlayer!.setLoopMode(LoopMode.one);
      if (!_isIncomingSessionActive(sessionId)) return;
      final ringtoneUrl = await _resolveIncomingRingtoneUrl();
      if (!_isIncomingSessionActive(sessionId)) return;
      await _incomingPlayer!.setUrl(ringtoneUrl);
      if (!_isIncomingSessionActive(sessionId)) return;
      await _incomingPlayer!.play();
      debugPrint('🔔 [CALL TONE] Started (incoming custom ringtone)');
      return;
    } on PlayerInterruptedException {
      debugPrint('🔕 [CALL TONE] URL ringtone interrupted (expected)');
      return;
    } catch (error) {
      debugPrint(
        '⚠️ [CALL TONE] URL ringtone failed, trying bundled asset: $error',
      );
    }

    // Last-resort fallback so incoming calls still notify the creator.
    if (!_isIncomingSessionActive(sessionId)) return;
    _playAlert();
    _timer = Timer.periodic(
      const Duration(milliseconds: 1200),
      (_) => _playAlert(),
    );
    debugPrint('🔔 [CALL TONE] Started (incoming system alert fallback)');
  }

  static bool _isIncomingSessionActive(int sessionId) {
    return _incomingSessionId == sessionId;
  }

  static void _stopActivePlaybackOnly() {
    _timer?.cancel();
    _timer = null;
    try {
      _incomingPlayer?.stop();
    } on PlayerInterruptedException {
      // Expected when a new source starts or stop races with play().
    } catch (error) {
      debugPrint('⚠️ [CALL TONE] Stop error: $error');
    }
    _activeMode = null;
  }

  static Future<String> _resolveIncomingRingtoneUrl() async {
    final cached = _cachedIncomingRingtoneUrl;
    if (cached != null && cached.isNotEmpty) return cached;

    final ref = FirebaseStorage.instance.ref().child(
      _incomingRingtoneStoragePath,
    );
    final url = await ref.getDownloadURL();
    _cachedIncomingRingtoneUrl = url;
    return url;
  }

  static void _playAlert() {
    // Best-effort sound playback. If platform blocks it, call flow continues.
    SystemSound.play(SystemSoundType.alert).catchError((error) {
      debugPrint('⚠️ [CALL TONE] Playback error: $error');
    });
  }
}
