import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../constants/app_constants.dart';
import '../../shared/models/user_model.dart';

/// Centralized Sentry configuration and helpers for Match Vibe.
class SentryService {
  SentryService._();

  /// Sentry SaaS org / project (dashboard: yagati / flutter).
  static const String orgSlug = 'yagati';
  static const String projectSlug = 'flutter';

  static bool _initialized = false;
  static bool _reportingActive = false;

  static final _recentFingerprintCache = <String, DateTime>{};
  static const _dedupWindow = Duration(seconds: 30);

  static const _breadcrumbMessageMax = 512;
  static const _breadcrumbDataValueMax = 256;
  static const _extraValueMax = 1024;
  static const _httpBodyMax = 1024;
  static const _maxStackFrames = 50;
  static const _softEventSizeCap = 200 * 1024;

  static final _sensitiveKeyPattern = RegExp(
    r'token|password|secret|dsn|email|phone|streamtoken|idtoken|firebase|authorization|cookie',
    caseSensitive: false,
  );

  static const _sensitiveHeaders = {
    'authorization',
    'cookie',
    'x-auth-token',
    'set-cookie',
  };

  /// Whether Sentry is active for this process (release + DSN, or debug verify build).
  static bool get isEnabled => _initialized && _reportingActive;

  /// Debug/profile builds can report when verifying setup (see [verifySetup]).
  static bool get allowDebugReporting => const bool.fromEnvironment(
        'SENTRY_ALLOW_DEBUG_REPORTING',
        defaultValue: false,
      );

  /// Show "Verify Sentry Setup" in account settings (dev tooling only).
  static bool get showVerifySetupUi => kDebugMode || kProfileMode;

  static bool _shouldEnableReporting(String? dsn) {
    if (dsn == null || dsn.isEmpty) return false;
    if (kReleaseMode) return true;
    return allowDebugReporting;
  }

  /// Resolve DSN: --dart-define > dotenv > disabled.
  static String? resolveDsn() {
    const fromDefine = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
    if (fromDefine.trim().isNotEmpty) return fromDefine.trim();
    final fromEnv = (dotenv.env['SENTRY_DSN'] ?? '').trim();
    if (fromEnv.isNotEmpty) return fromEnv;
    return null;
  }

  static double _resolveTracesSampleRate() {
    const fromDefine = String.fromEnvironment(
      'SENTRY_TRACES_SAMPLE_RATE',
      defaultValue: '',
    );
    if (fromDefine.trim().isNotEmpty) {
      return double.tryParse(fromDefine.trim()) ?? 0.15;
    }
    final fromEnv = (dotenv.env['SENTRY_TRACES_SAMPLE_RATE'] ?? '').trim();
    if (fromEnv.isNotEmpty) {
      return double.tryParse(fromEnv) ?? 0.15;
    }
    return kReleaseMode ? 0.15 : 0.0;
  }

  /// Intentional error for Sentry dashboard "Verify" (throws [StateError]).
  static Never verifySetup() {
    throw StateError('This is test exception');
  }

  /// Human-readable hint when verify is not available.
  static String? get verifySetupBlockedReason {
    if (resolveDsn() == null) {
      return 'Set SENTRY_DSN in .env or --dart-define=SENTRY_DSN=...';
    }
    if (!_reportingActive && (kDebugMode || kProfileMode)) {
      return 'Debug verify: flutter run --dart-define=SENTRY_ALLOW_DEBUG_REPORTING=true '
          '(with DSN set). Or use a release build.';
    }
    if (!_reportingActive) {
      return 'Sentry is not initialized for this build.';
    }
    return null;
  }

  static List<String> _tracePropagationTargets() {
    final targets = <String>{'localhost', '127.0.0.1'};
    for (final raw in [AppConstants.baseUrl, AppConstants.socketUrl]) {
      final host = Uri.tryParse(raw)?.host ?? '';
      if (host.isNotEmpty) {
        targets.add(host);
        final scheme = Uri.tryParse(raw)?.scheme ?? 'https';
        targets.add('$scheme://$host');
      }
    }
    return targets.toList();
  }

  /// Wrap app startup in [SentryFlutter.init].
  static Future<void> init(Future<void> Function() appRunner) async {
    final resolvedDsn = resolveDsn();
    final enabled = _shouldEnableReporting(resolvedDsn);
    final packageInfo = await PackageInfo.fromPlatform();
    final release = 'matchvibe@${packageInfo.version}+${packageInfo.buildNumber}';

    await SentryFlutter.init(
      (options) {
        options.dsn = enabled ? resolvedDsn : '';
        options.environment = kReleaseMode ? 'production' : 'development';
        options.release = release;
        options.dist = packageInfo.buildNumber;
        options.tracesSampleRate = enabled ? _resolveTracesSampleRate() : 0.0;
        options.profilesSampleRate = 0.0;
        options.sendDefaultPii = false;
        options.attachStacktrace = true;
        options.maxBreadcrumbs = 100;
        options.enableAutoSessionTracking = enabled;

        if (enabled) {
          options.tracePropagationTargets
            ..clear()
            ..addAll(_tracePropagationTargets());
        }

        if (Platform.isAndroid && enabled) {
          options.anrEnabled = true;
        }

        options.beforeSend = enabled
            ? (event, hint) {
                final scrubbed = _scrubEvent(event);
                if (scrubbed == null) return null;
                final truncated = _truncateEventPayloads(scrubbed);
                return _shouldDropDuplicateEvent(truncated) ? null : truncated;
              }
            : null;
        options.beforeBreadcrumb = enabled ? _scrubBreadcrumb : null;
      },
      appRunner: () async {
        _initialized = true;
        _reportingActive = enabled;
        if (enabled) {
          await setGlobalTags();
        }
        await appRunner();
      },
    );
  }

  static Future<void> setGlobalTags() async {
    if (!isEnabled) return;
    await Sentry.configureScope((scope) {
      scope.setTag('platform', Platform.operatingSystem);
      final host = Uri.tryParse(AppConstants.baseUrl)?.host ?? '';
      if (host.isNotEmpty) {
        scope.setTag('api_base_host', host);
      }
    });
  }

  static Future<void> setUserContext({
    required UserModel user,
    required String firebaseUid,
  }) async {
    if (!isEnabled) return;
    await Sentry.configureScope((scope) {
      scope.setUser(SentryUser(id: user.id));
      scope.setTag('role', user.role ?? 'unknown');
      scope.setTag('firebase_uid', firebaseUid);
    });
  }

  static Future<void> clearUserContext() async {
    if (!isEnabled) return;
    await Sentry.configureScope((scope) {
      scope.setUser(null);
      scope.removeTag('role');
      scope.removeTag('firebase_uid');
    });
  }

  static Future<void> setScreenTag(String screen) async {
    if (!isEnabled) return;
    await Sentry.configureScope((scope) {
      scope.setTag('screen', screen);
    });
  }

  static Future<void> clearScreenTag() async {
    if (!isEnabled) return;
    await Sentry.configureScope((scope) {
      scope.removeTag('screen');
    });
  }

  static void addBreadcrumb({
    required String category,
    required String message,
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? data,
  }) {
    if (!isEnabled) return;
    Sentry.addBreadcrumb(
      Breadcrumb(
        category: category,
        message: _truncateString(message, _breadcrumbMessageMax),
        level: level,
        data: data == null ? null : _scrubMap(data, maxValueLen: _breadcrumbDataValueMax),
      ),
    );
  }

  static Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
    Map<String, String>? tags,
    Map<String, String>? extra,
  }) async {
    if (!isEnabled) return;
    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      withScope: (scope) {
        tags?.forEach(scope.setTag);
        extra?.forEach((key, value) {
          scope.setTag('extra_$key', _truncateString(value, 128));
        });
      },
    );
  }

  static Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.warning,
    Map<String, String>? tags,
  }) async {
    if (!isEnabled) return;
    await Sentry.captureMessage(
      _truncateString(message, _breadcrumbMessageMax),
      level: level,
      withScope: (scope) {
        tags?.forEach(scope.setTag);
      },
    );
  }

  static ISentrySpan startTransaction(String name, String operation) {
    return Sentry.startTransaction(name, operation, bindToScope: true);
  }

  /// Selective API error reporting — avoids 4xx/timeout flooding.
  static bool shouldReportApiError(DioException error) {
    if (!isEnabled) return false;
    if (error.type == DioExceptionType.cancel) return false;
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return false;
    }

    final status = error.response?.statusCode;
    if (status == 401) return false;

    final path = error.requestOptions.path.toLowerCase();
    const criticalPrefixes = [
      '/billing',
      '/payment',
      '/video',
      '/chat',
      '/creator/withdraw',
    ];

    if (status != null && status >= 500) {
      return criticalPrefixes.any(path.contains);
    }

    return false;
  }

  static Breadcrumb? _scrubBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
    if (breadcrumb == null) return null;
    final data = breadcrumb.data;
    if (data == null) return breadcrumb;
    return Breadcrumb(
      category: breadcrumb.category,
      message: breadcrumb.message == null
          ? null
          : _truncateString(breadcrumb.message!, _breadcrumbMessageMax),
      level: breadcrumb.level,
      type: breadcrumb.type,
      timestamp: breadcrumb.timestamp,
      data: _scrubMap(Map<String, dynamic>.from(data)),
    );
  }

  static SentryEvent? _scrubEvent(SentryEvent event) {
    final exceptions = event.exceptions;
    if (exceptions != null && exceptions.isNotEmpty) {
      final first = exceptions.first;
      final value = first.value?.toLowerCase() ?? '';
      if (value.contains('permission denied') ||
          value.contains('user cancelled') ||
          value.contains('cancelled')) {
        return null;
      }
    }

    _scrubResponseContext(event.contexts);

    final scrubbedBreadcrumbs = event.breadcrumbs?.map((b) {
      return Breadcrumb(
        category: b.category,
        message: b.message == null
            ? null
            : _truncateString(b.message!, _breadcrumbMessageMax),
        level: b.level,
        type: b.type,
        timestamp: b.timestamp,
        data: b.data == null
            ? null
            : _scrubMap(Map<String, dynamic>.from(b.data!)),
      );
    }).toList();

    return event.copyWith(
      breadcrumbs: scrubbedBreadcrumbs,
      user: event.user == null ? null : SentryUser(id: event.user!.id),
    );
  }

  static void _scrubResponseContext(Contexts contexts) {
    final response = contexts.response;
    if (response == null) return;

    final scrubbedHeaders = Map<String, String>.from(response.headers);
    for (final key in scrubbedHeaders.keys.toList()) {
      if (_sensitiveHeaders.contains(key.toLowerCase())) {
        scrubbedHeaders[key] = '[Filtered]';
      }
    }

    Object? data = response.data;
    if (data is String && data.length > _httpBodyMax) {
      data = _truncateString(data, _httpBodyMax);
    }

    contexts[SentryResponse.type] = SentryResponse(
      statusCode: response.statusCode,
      headers: scrubbedHeaders,
      bodySize: response.bodySize,
      cookies: response.cookies,
      data: data,
    );
  }

  static Map<String, dynamic> _scrubMap(
    Map<String, dynamic> input, {
    int maxValueLen = _extraValueMax,
    int maxKeys = 20,
  }) {
    final out = <String, dynamic>{};
    var count = 0;
    for (final entry in input.entries) {
      if (count >= maxKeys) break;
      final key = entry.key;
      if (_sensitiveKeyPattern.hasMatch(key) ||
          _sensitiveHeaders.contains(key.toLowerCase())) {
        out[key] = '[Filtered]';
      } else if (entry.value is String) {
        out[key] = _truncateString(entry.value as String, maxValueLen);
      } else if (entry.value is Map) {
        out[key] = _scrubMap(
          Map<String, dynamic>.from(entry.value as Map),
          maxValueLen: maxValueLen,
          maxKeys: 3,
        );
      } else {
        out[key] = entry.value;
      }
      count++;
    }
    return out;
  }

  static SentryEvent _truncateEventPayloads(SentryEvent event) {
    var breadcrumbs = event.breadcrumbs?.map((b) {
      return Breadcrumb(
        category: b.category,
        message: b.message == null
            ? null
            : _truncateString(b.message!, _breadcrumbMessageMax),
        level: b.level,
        type: b.type,
        timestamp: b.timestamp,
        data: b.data == null
            ? null
            : _scrubMap(
                Map<String, dynamic>.from(b.data!),
                maxValueLen: _breadcrumbDataValueMax,
                maxKeys: 3,
              ),
      );
    }).toList();

    if (breadcrumbs != null && breadcrumbs.length > 100) {
      breadcrumbs = breadcrumbs.sublist(breadcrumbs.length - 100);
    }

    var exceptions = event.exceptions;
    if (exceptions != null && exceptions.length > _maxStackFrames) {
      exceptions = exceptions.sublist(0, _maxStackFrames);
    }

    return event.copyWith(
      breadcrumbs: breadcrumbs,
      exceptions: exceptions,
    );
  }

  static int _estimateEventSize(SentryEvent event) {
    var size = 0;
    for (final b in event.breadcrumbs ?? const <Breadcrumb>[]) {
      size += (b.message?.length ?? 0);
      if (b.data != null) {
        size += b.data!.values.whereType<String>().fold<int>(
          0,
          (sum, s) => sum + s.length,
        );
      }
    }
    return size;
  }

  static bool _shouldDropDuplicateEvent(SentryEvent event) {
    final now = DateTime.now();
    _pruneFingerprintCache(now);

    final fingerprint = _buildFingerprint(event);
    final lastSeen = _recentFingerprintCache[fingerprint];
    if (lastSeen != null && now.difference(lastSeen) < _dedupWindow) {
      return true;
    }
    _recentFingerprintCache[fingerprint] = now;
    return false;
  }

  static void _pruneFingerprintCache(DateTime now) {
    _recentFingerprintCache.removeWhere(
      (_, ts) => now.difference(ts) > _dedupWindow,
    );
  }

  static String _buildFingerprint(SentryEvent event) {
    if (event.fingerprint != null && event.fingerprint!.isNotEmpty) {
      return event.fingerprint!.join('|');
    }

    final parts = <String>[];

    final exceptions = event.exceptions;
    if (exceptions != null && exceptions.isNotEmpty) {
      final ex = exceptions.first;
      parts.add(ex.type ?? 'unknown');
      final value = ex.value ?? '';
      parts.add(value.split('\n').first.trim());
    } else {
      parts.add(event.message?.formatted ?? 'message');
    }

    final tags = event.tags ?? const {};
    for (final key in [
      'screen',
      'call_phase',
      'failure_reason',
      'stream',
      'call_id',
      'http.path',
      'http.status',
    ]) {
      final tagVal = tags[key];
      if (tagVal != null) parts.add('$key:$tagVal');
    }

    return parts.join('|');
  }

  static String _truncateString(String value, int maxLen) {
    if (value.length <= maxLen) return value;
    return '${value.substring(0, maxLen)}…';
  }
}
