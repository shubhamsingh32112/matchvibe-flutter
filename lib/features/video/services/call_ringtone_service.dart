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

  static void startOutgoingTone() {
    _start(
      mode: _CallToneMode.outgoing,
      interval: const Duration(milliseconds: 1700),
    );
  }

  static void startIncomingRingtone() {
    unawaited(_startIncomingRingtoneInternal());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _incomingPlayer?.stop();
    _activeMode = null;
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

  static Future<void> _startIncomingRingtoneInternal() async {
    if (_activeMode == _CallToneMode.incoming) return;

    stop();
    _activeMode = _CallToneMode.incoming;

    // Immediate feedback so the user hears something right away.
    _playAlert();

    // Start with bundled asset ringtone (fast, offline).
    try {
      _incomingPlayer ??= AudioPlayer();
      await _incomingPlayer!.setLoopMode(LoopMode.one);
      await _incomingPlayer!.setAsset(_incomingRingtoneAssetPath);
      await _incomingPlayer!.play();
      debugPrint('🔔 [CALL TONE] Started (incoming bundled ringtone)');
    } catch (error) {
      debugPrint(
        '⚠️ [CALL TONE] Asset ringtone failed, will try URL/fallback: $error',
      );
    }

    // Best-effort upgrade to remote URL ringtone (do not block ring start).
    unawaited(() async {
      if (_activeMode != _CallToneMode.incoming) return;
      try {
        _incomingPlayer ??= AudioPlayer();
        await _incomingPlayer!.setLoopMode(LoopMode.one);
        final ringtoneUrl = await _resolveIncomingRingtoneUrl();
        if (_activeMode != _CallToneMode.incoming) return;
        await _incomingPlayer!.setUrl(ringtoneUrl);
        if (_activeMode != _CallToneMode.incoming) return;
        await _incomingPlayer!.play();
        debugPrint('🔔 [CALL TONE] Upgraded to incoming custom ringtone URL');
      } catch (_) {
        // Keep bundled ringtone if playing; otherwise fallback timer below.
      }
    }());

    try {
      _incomingPlayer ??= AudioPlayer();
      await _incomingPlayer!.setLoopMode(LoopMode.one);
      final ringtoneUrl = await _resolveIncomingRingtoneUrl();
      await _incomingPlayer!.setUrl(ringtoneUrl);
      await _incomingPlayer!.play();
      debugPrint('🔔 [CALL TONE] Started (incoming custom ringtone)');
      return;
    } catch (error) {
      debugPrint(
        '⚠️ [CALL TONE] URL ringtone failed, trying bundled asset: $error',
      );
    }

    try {
      _incomingPlayer ??= AudioPlayer();
      await _incomingPlayer!.setLoopMode(LoopMode.one);
      await _incomingPlayer!.setAsset(_incomingRingtoneAssetPath);
      await _incomingPlayer!.play();
      debugPrint('🔔 [CALL TONE] Started (incoming bundled ringtone)');
      return;
    } catch (error) {
      debugPrint(
        '⚠️ [CALL TONE] Asset ringtone failed, using alert sound: $error',
      );
    }

    // Last-resort fallback so incoming calls still notify the creator.
    _playAlert();
    _timer = Timer.periodic(
      const Duration(milliseconds: 1200),
      (_) => _playAlert(),
    );
    debugPrint('🔔 [CALL TONE] Started (incoming system alert fallback)');
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
