import '../../../core/services/sentry_service.dart';

/// Session-scoped billing/socket convergence counters (reset per call).
class BillingConvergenceMetrics {
  BillingConvergenceMetrics._();

  static final BillingConvergenceMetrics instance = BillingConvergenceMetrics._();

  int socketReconnectCount = 0;
  int socketReconnectDurationMs = 0;
  int recoverRequestCount = 0;
  int recoverRetryCount = 0;
  int recoverDuplicateCount = 0;
  int recoverAppliedCount = 0;
  int? lastRecoverLatencyMs;

  DateTime? _lastDisconnectAt;
  int? _lastRecoverRequestAtMs;

  void onSocketDisconnect() {
    _lastDisconnectAt = DateTime.now();
  }

  void onSocketReconnect() {
    socketReconnectCount++;
    if (_lastDisconnectAt != null) {
      socketReconnectDurationMs += DateTime.now()
          .difference(_lastDisconnectAt!)
          .inMilliseconds;
      _lastDisconnectAt = null;
    }
  }

  void onRecoverRequest() {
    recoverRequestCount++;
    _lastRecoverRequestAtMs = DateTime.now().millisecondsSinceEpoch;
  }

  void onRecoverRetry() => recoverRetryCount++;

  void onRecoverDuplicate() => recoverDuplicateCount++;

  void onRecoverApplied() {
    recoverAppliedCount++;
    final started = _lastRecoverRequestAtMs;
    if (started != null) {
      lastRecoverLatencyMs =
          DateTime.now().millisecondsSinceEpoch - started;
    }
  }

  Map<String, num> snapshot() => {
        'socket_reconnect_count': socketReconnectCount,
        'socket_reconnect_duration_ms': socketReconnectDurationMs,
        'recover_request_count': recoverRequestCount,
        'recover_retry_count': recoverRetryCount,
        'recover_duplicate_count': recoverDuplicateCount,
        'recover_applied_count': recoverAppliedCount,
        if (lastRecoverLatencyMs != null)
          'recover_latency_ms': lastRecoverLatencyMs!,
      };

  void reset() {
    socketReconnectCount = 0;
    socketReconnectDurationMs = 0;
    recoverRequestCount = 0;
    recoverRetryCount = 0;
    recoverDuplicateCount = 0;
    recoverAppliedCount = 0;
    lastRecoverLatencyMs = null;
    _lastDisconnectAt = null;
    _lastRecoverRequestAtMs = null;
  }

  void flushToSentry({String? callId}) {
    final data = snapshot().map((k, v) => MapEntry(k, v.toString()));
    if (callId != null && callId.isNotEmpty) {
      data['call_id'] = callId;
    }
    SentryService.addThrottledBreadcrumb(
      category: 'billing.convergence',
      message: 'billing.convergence.metrics',
      data: data,
    );
  }
}
