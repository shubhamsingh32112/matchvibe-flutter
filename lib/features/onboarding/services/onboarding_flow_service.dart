import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../models/onboarding_step.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';

class OnboardingFlowService {
  /// Called after a successful `POST /user/onboarding/stage` (e.g. refresh auth
  /// `onboardingStage`). Set from app bootstrap; cleared on dispose.
  static Future<void> Function()? _afterStageAdvanceSuccess;

  static void setAfterStageAdvanceSuccess(Future<void> Function()? fn) {
    _afterStageAdvanceSuccess = fn;
  }

  static const int onboardingFlowVersion = 2;
  static const String _welcomePrefix = 'onboarding_welcome_seen';
  static const String _permissionsPrefix = 'onboarding_permissions_seen';
  static const String _completedPrefix = 'onboarding_completed';
  static const String _idemStagePrefix = 'idempotency_onboarding_stage_v1';
  static const String _idemPermPrefix = 'idempotency_onboarding_perm_v1';
  static const String _mutationPrefix = 'onboarding_client_mutation_v1';
  static const int _idemTtlMs = 24 * 60 * 60 * 1000;

  static String _k(String prefix, String uid) => '${prefix}_$uid';
  static final Map<String, OnboardingStep> _localStageOverrideByUid =
      <String, OnboardingStep>{};

  static int _stageRank(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.welcome:
        return 1;
      case OnboardingStep.permission:
        return 2;
      case OnboardingStep.completed:
        return 3;
    }
  }

  static void setLocalStageOverride({
    required String firebaseUid,
    required OnboardingStep step,
  }) {
    _localStageOverrideByUid[firebaseUid] = step;
  }

  static void clearLocalStageOverride(String firebaseUid) {
    _localStageOverrideByUid.remove(firebaseUid);
  }

  static OnboardingStep? _fromServerStage(String? stage) {
    switch (stage) {
      case OnboardingStageContract.welcome:
        return OnboardingStep.welcome;
      case OnboardingStageContract.permission:
      case 'permissions':
        return OnboardingStep.permission;
      case OnboardingStageContract.completed:
        return OnboardingStep.completed;
      case 'bonus':
        return OnboardingStep.permission;
      default:
        return null;
    }
  }

  static Future<OnboardingStep> nextStep({
    required String firebaseUid,
    required bool bonusAlreadyClaimed,
    String? serverStage,
  }) async {
    final serverStep = _fromServerStage(serverStage);
    final localOverride = _localStageOverrideByUid[firebaseUid];
    if (serverStep != null &&
        localOverride != null &&
        _stageRank(serverStep) >= _stageRank(localOverride)) {
      _localStageOverrideByUid.remove(firebaseUid);
    }
    final effectiveServerStep = (serverStep != null &&
            localOverride != null &&
            _stageRank(localOverride) > _stageRank(serverStep))
        ? localOverride
        : serverStep;
    if (effectiveServerStep != null && _isServerAuthoritativeFlowEnabled()) {
      return effectiveServerStep;
    }

    final prefs = await SharedPreferences.getInstance();

    final completed = prefs.getBool(_k(_completedPrefix, firebaseUid)) ?? false;
    if (completed) return OnboardingStep.completed;

    final welcomeSeen = prefs.getBool(_k(_welcomePrefix, firebaseUid)) ?? false;
    if (!welcomeSeen) return OnboardingStep.welcome;

    final permissionsSeen =
        prefs.getBool(_k(_permissionsPrefix, firebaseUid)) ?? false;
    if (!permissionsSeen) return OnboardingStep.permission;

    return OnboardingStep.completed;
  }

  /// Ensures server stage is at least `permissions` before accept (v2 strict path).
  static Future<void> ensureServerAtPermissionsStage({
    required String firebaseUid,
    String? serverStage,
    String? sessionId,
  }) async {
    final stage = serverStage?.trim() ?? '';
    if (stage == 'permission' ||
        stage == 'permissions' ||
        stage == OnboardingStageContract.completed) {
      return;
    }
    if (stage == OnboardingStageContract.welcome || stage == 'bonus' || stage.isEmpty) {
      await markWelcomeSeen(firebaseUid, sessionId: sessionId);
      await markPermissionsSeen(firebaseUid, sessionId: sessionId);
    }
  }

  static Future<void> markWelcomeSeen(
    String firebaseUid, {
    String? sessionId,
  }) async {
    await _advanceOnServer(
      firebaseUid: firebaseUid,
      stage: OnboardingStageContract.welcome,
      event: 'welcome_seen',
      sessionId: sessionId,
      mutationStep: OnboardingStep.welcome,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_k(_welcomePrefix, firebaseUid), true);
  }

  static Future<void> markPermissionsSeen(
    String firebaseUid, {
    String? sessionId,
  }) async {
    await _advanceOnServer(
      firebaseUid: firebaseUid,
      stage: OnboardingStageContract.permission,
      event: 'permissions_not_now',
      sessionId: sessionId,
      mutationStep: OnboardingStep.permission,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_k(_permissionsPrefix, firebaseUid), true);
  }

  /// Local-only completion for non-user roles; do not POST stage=completed.
  static Future<void> markLocalCompleted(String firebaseUid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_k(_completedPrefix, firebaseUid), true);
    await prefs.setBool(_k(_welcomePrefix, firebaseUid), true);
    await prefs.setBool(_k(_permissionsPrefix, firebaseUid), true);
  }

  static Future<void> clearLocalFlags(String firebaseUid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_k(_welcomePrefix, firebaseUid));
    await prefs.remove(_k(_permissionsPrefix, firebaseUid));
    await prefs.remove(_k(_completedPrefix, firebaseUid));
  }

  static String _idemKey(String prefix, String uid, String suffix) =>
      '${prefix}_${uid}_$suffix';

  static Future<String> _loadOrCreateClientMutationId({
    required String firebaseUid,
    required OnboardingStep step,
    String? sessionId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _idemKey(_mutationPrefix, firebaseUid, step.name);
    final now = DateTime.now().millisecondsSinceEpoch;
    final raw = prefs.getString(key);
    if (raw != null && raw.isNotEmpty) {
      final parts = raw.split('|');
      if (parts.length == 2) {
        final createdAt = int.tryParse(parts[0]) ?? 0;
        final value = parts[1];
        if (createdAt > 0 && (now - createdAt) <= _idemTtlMs && value.isNotEmpty) {
          return value;
        }
      }
    }
    final sessionPart = sessionId ?? 'nosession';
    final value = 'ob_${firebaseUid}_${step.name}_${sessionPart}_$now';
    await prefs.setString(key, '$now|$value');
    return value;
  }

  static Future<String> _loadOrCreateStageIdempotencyKey({
    required String firebaseUid,
    required String event,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _idemKey(_idemStagePrefix, firebaseUid, event);
    final now = DateTime.now().millisecondsSinceEpoch;
    final raw = prefs.getString(key);
    if (raw != null && raw.isNotEmpty) {
      final parts = raw.split('|');
      if (parts.length == 2) {
        final createdAt = int.tryParse(parts[0]) ?? 0;
        final value = parts[1];
        if (createdAt > 0 && (now - createdAt) <= _idemTtlMs && value.isNotEmpty) {
          return value;
        }
      }
    }
    final value = 'onboarding-$firebaseUid-$event-$now';
    await prefs.setString(key, '$now|$value');
    return value;
  }

  static Future<void> _clearStageIdempotencyKey({
    required String firebaseUid,
    required String event,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_idemKey(_idemStagePrefix, firebaseUid, event));
  }

  static Map<String, String> _onboardingHeaders({
    required String idempotencyKey,
    String? sessionId,
    String? clientMutationId,
  }) {
    return {
      'X-Idempotency-Key': idempotencyKey,
      'X-Onboarding-Flow-Version': '$onboardingFlowVersion',
      if (sessionId != null) 'X-Onboarding-Session-Id': sessionId,
      if (clientMutationId != null && clientMutationId.isNotEmpty)
        'X-Client-Mutation-Id': clientMutationId,
    };
  }

  static Future<void> _advanceOnServer({
    required String firebaseUid,
    required String stage,
    required String event,
    String? sessionId,
    required OnboardingStep mutationStep,
  }) async {
    const retries = 3;
    final key = await _loadOrCreateStageIdempotencyKey(
      firebaseUid: firebaseUid,
      event: event,
    );
    final clientMutationId = await _loadOrCreateClientMutationId(
      firebaseUid: firebaseUid,
      step: mutationStep,
      sessionId: sessionId,
    );
    for (var attempt = 1; attempt <= retries; attempt++) {
      try {
        await ApiClient()
            .post(
              '/user/onboarding/stage',
              data: {
                'stage': stage,
                'clientMutationId': clientMutationId,
              },
              headers: _onboardingHeaders(
                idempotencyKey: key,
                sessionId: sessionId,
                clientMutationId: clientMutationId,
              ),
            )
            .timeout(const Duration(seconds: 4));
        try {
          await _afterStageAdvanceSuccess?.call();
        } catch (_) {
          // Non-fatal: server stage already advanced; profile can refresh later.
        }
        await _clearStageIdempotencyKey(firebaseUid: firebaseUid, event: event);
        return;
      } catch (e) {
        if (attempt == retries) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
      }
    }
  }

  static Future<Map<String, dynamic>> submitPermissionsDecision({
    required String firebaseUid,
    required PermissionsDecision decision,
    required String cameraMicStatus,
    required String notificationStatus,
    String? sessionId,
    String? serverStage,
  }) async {
    if (decision == PermissionsDecision.accept) {
      await ensureServerAtPermissionsStage(
        firebaseUid: firebaseUid,
        serverStage: serverStage,
        sessionId: sessionId,
      );
    }

    final requestId = await _loadOrCreatePermRequestId(
      firebaseUid: firebaseUid,
      decision: decision.wireValue,
    );
    final clientMutationId = await _loadOrCreateClientMutationId(
      firebaseUid: firebaseUid,
      step: OnboardingStep.permission,
      sessionId: sessionId,
    );
    final response = await ApiClient().post(
      '/user/onboarding/permissions-decision',
      data: {
        'decision': decision.wireValue,
        'requestId': requestId,
        'cameraMicStatus': cameraMicStatus,
        'notificationStatus': notificationStatus,
        'clientMutationId': clientMutationId,
      },
      headers: _onboardingHeaders(
        idempotencyKey: requestId,
        sessionId: sessionId,
        clientMutationId: clientMutationId,
      ),
    );
    await _clearPermRequestId(firebaseUid: firebaseUid, decision: decision.wireValue);
    if (decision == PermissionsDecision.accept) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_k(_completedPrefix, firebaseUid), true);
    }
    final data = response.data as Map<String, dynamic>;
    return (data['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  static Future<String> _loadOrCreatePermRequestId({
    required String firebaseUid,
    required String decision,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _idemKey(_idemPermPrefix, firebaseUid, decision);
    final now = DateTime.now().millisecondsSinceEpoch;
    final raw = prefs.getString(key);
    if (raw != null && raw.isNotEmpty) {
      final parts = raw.split('|');
      if (parts.length == 2) {
        final createdAt = int.tryParse(parts[0]) ?? 0;
        final value = parts[1];
        if (createdAt > 0 && (now - createdAt) <= _idemTtlMs && value.isNotEmpty) {
          return value;
        }
      }
    }
    final random = Random.secure().nextInt(1 << 32).toRadixString(16);
    final value = 'perm_${DateTime.now().microsecondsSinceEpoch}_$random';
    await prefs.setString(key, '$now|$value');
    return value;
  }

  static Future<void> _clearPermRequestId({
    required String firebaseUid,
    required String decision,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_idemKey(_idemPermPrefix, firebaseUid, decision));
  }

  static bool _isServerAuthoritativeFlowEnabled() {
    try {
      return AppConstants.enableServerOnboardingFlow ||
          AppConstants.enableDeterministicOnboardingRunner;
    } catch (_) {
      return true;
    }
  }
}

enum PermissionsDecision {
  accept('accept'),
  notNow('not_now');

  final String wireValue;
  const PermissionsDecision(this.wireValue);
}
