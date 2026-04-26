import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/onboarding_step.dart';

class OnboardingPopupState {
  final bool seen;
  final bool enqueued;
  final bool shown;
  final bool completed;
  final int retryCount;
  final int lastAttemptAtMs;
  final int updatedAtMs;

  const OnboardingPopupState({
    required this.seen,
    required this.enqueued,
    required this.shown,
    required this.completed,
    required this.retryCount,
    required this.lastAttemptAtMs,
    required this.updatedAtMs,
  });

  factory OnboardingPopupState.initial() {
    return const OnboardingPopupState(
      seen: false,
      enqueued: false,
      shown: false,
      completed: false,
      retryCount: 0,
      lastAttemptAtMs: 0,
      updatedAtMs: 0,
    );
  }

  OnboardingPopupState copyWith({
    bool? seen,
    bool? enqueued,
    bool? shown,
    bool? completed,
    int? retryCount,
    int? lastAttemptAtMs,
    int? updatedAtMs,
  }) {
    return OnboardingPopupState(
      seen: seen ?? this.seen,
      enqueued: enqueued ?? this.enqueued,
      shown: shown ?? this.shown,
      completed: completed ?? this.completed,
      retryCount: retryCount ?? this.retryCount,
      lastAttemptAtMs: lastAttemptAtMs ?? this.lastAttemptAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'seen': seen,
        'enqueued': enqueued,
        'shown': shown,
        'completed': completed,
        'retryCount': retryCount,
        'lastAttemptAtMs': lastAttemptAtMs,
        'updatedAtMs': updatedAtMs,
      };

  static OnboardingPopupState fromJson(Map<String, dynamic> json) {
    return OnboardingPopupState(
      seen: json['seen'] == true,
      enqueued: json['enqueued'] == true,
      shown: json['shown'] == true,
      completed: json['completed'] == true,
      retryCount: (json['retryCount'] is num) ? (json['retryCount'] as num).toInt() : 0,
      lastAttemptAtMs:
          (json['lastAttemptAtMs'] is num) ? (json['lastAttemptAtMs'] as num).toInt() : 0,
      updatedAtMs: (json['updatedAtMs'] is num) ? (json['updatedAtMs'] as num).toInt() : 0,
    );
  }
}

class OnboardingPopupStateService {
  static const String _prefix = 'onboarding_popup_state_v1';

  static String _key({required String uid, required OnboardingStep step}) =>
      '${_prefix}_${uid}_${step.name}';

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  static OnboardingPopupState? _parseRaw(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return OnboardingPopupState.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static OnboardingPopupState _repair(OnboardingPopupState s) {
    var state = s;
    // Invariant 1: completed implies all prior states.
    if (state.completed) {
      state = state.copyWith(seen: true, enqueued: true, shown: true);
    }
    // Invariant 2: shown implies enqueued.
    if (state.shown && !state.enqueued) {
      state = state.copyWith(enqueued: true);
    }
    // Invariant 3: enqueued implies seen.
    if (state.enqueued && !state.seen) {
      state = state.copyWith(seen: true);
    }
    return state;
  }

  static Future<OnboardingPopupState> read({
    required String uid,
    required OnboardingStep step,
  }) async {
    final prefs = await _prefs();
    final raw = prefs.getString(_key(uid: uid, step: step));
    if (raw == null || raw.trim().isEmpty) {
      return OnboardingPopupState.initial();
    }
    final parsed = _parseRaw(raw);
    if (parsed == null) return OnboardingPopupState.initial();
    final repaired = _repair(parsed);
    // Persist repaired state if it changed materially (repair is a "newer" write).
    if (repaired.toJson().toString() != parsed.toJson().toString()) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _write(
        prefs,
        uid: uid,
        step: step,
        state: repaired,
        updatedAtMs: now,
      );
    }
    return repaired;
  }

  static Future<void> clearAllForUser(String uid) async {
    final prefs = await _prefs();
    for (final step in _orderedSteps()) {
      await prefs.remove(_key(uid: uid, step: step));
    }
  }

  static List<OnboardingStep> _orderedSteps() => const <OnboardingStep>[
        OnboardingStep.welcome,
        OnboardingStep.bonus,
        OnboardingStep.permission,
      ];

  static Future<void> _write(
    SharedPreferences prefs, {
    required String uid,
    required OnboardingStep step,
    required OnboardingPopupState state,
    required int updatedAtMs,
  }) async {
    // Last-write-wins guard: prevent stale overwrites that can regress completion.
    final existingRaw = prefs.getString(_key(uid: uid, step: step));
    if (existingRaw != null && existingRaw.trim().isNotEmpty) {
      final existing = _parseRaw(existingRaw);
      if (existing != null && existing.updatedAtMs > updatedAtMs) {
        return; // drop stale write
      }
    }
    final repaired = _repair(state).copyWith(updatedAtMs: updatedAtMs);
    await prefs.setString(
      _key(uid: uid, step: step),
      jsonEncode(repaired.toJson()),
    );
  }

  static Future<void> _update(
    SharedPreferences prefs, {
    required String uid,
    required OnboardingStep step,
    required OnboardingPopupState Function(OnboardingPopupState current) fn,
  }) async {
    // Use an "intent time" timestamp so out-of-order persistence can't regress state.
    final intentAtMs = DateTime.now().millisecondsSinceEpoch;
    final current = await read(uid: uid, step: step);
    await _write(
      prefs,
      uid: uid,
      step: step,
      state: fn(current),
      updatedAtMs: intentAtMs,
    );
  }

  static Future<void> markSeen({required String uid, required OnboardingStep step}) async {
    final prefs = await _prefs();
    await _update(
      prefs,
      uid: uid,
      step: step,
      fn: (c) => c.copyWith(seen: true),
    );
  }

  static Future<void> markEnqueued({required String uid, required OnboardingStep step}) async {
    final prefs = await _prefs();
    await _update(
      prefs,
      uid: uid,
      step: step,
      fn: (c) => c.copyWith(enqueued: true),
    );
  }

  static Future<void> markShown({required String uid, required OnboardingStep step}) async {
    final prefs = await _prefs();
    await _update(
      prefs,
      uid: uid,
      step: step,
      fn: (c) => c.copyWith(shown: true),
    );
  }

  static Future<void> markCompleted({required String uid, required OnboardingStep step}) async {
    final prefs = await _prefs();
    await _update(
      prefs,
      uid: uid,
      step: step,
      fn: (c) => c.copyWith(completed: true),
    );
  }

  static Future<void> recordRecoveryAttempt({
    required String uid,
    required OnboardingStep step,
  }) async {
    final prefs = await _prefs();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _update(
      prefs,
      uid: uid,
      step: step,
      fn: (c) => c.copyWith(
        retryCount: c.retryCount + 1,
        lastAttemptAtMs: now,
      ),
    );
  }

  static bool shouldRecoverNow(
    OnboardingPopupState state, {
    required int nowMs,
  }) {
    if (!state.seen) return false;
    if (state.completed) return false;
    if (state.shown) return false;
    if (state.retryCount >= 3) return false;
    final last = state.lastAttemptAtMs;
    if (last > 0 && (nowMs - last) <= 5000) return false;
    return true;
  }
}

