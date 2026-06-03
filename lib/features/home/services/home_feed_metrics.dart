import 'package:flutter/foundation.dart';
import '../../../core/services/sentry_service.dart';

/// Lightweight counters for home feed presence hardening (debug + Sentry breadcrumbs).
class HomeFeedMetrics {
  HomeFeedMetrics._();

  static int socketInsertionsTotal = 0;
  static int socketInsertionsDeduplicated = 0;
  static int socketInsertionsRejectedCap = 0;
  static int byUidFetchTotal = 0;
  static int byUidFetchFailures = 0;
  static int statusEventsReceived = 0;

  static void recordSocketInsertion() {
    socketInsertionsTotal++;
    _breadcrumb('creator_socket_insertions_total', socketInsertionsTotal);
  }

  static void recordSocketInsertionDeduplicated(int dropped) {
    if (dropped <= 0) return;
    socketInsertionsDeduplicated += dropped;
    _breadcrumb('creator_socket_insertions_deduplicated', dropped);
  }

  static void recordSocketInsertionRejectedCap() {
    socketInsertionsRejectedCap++;
    _breadcrumb('creator_socket_insertions_rejected_cap', socketInsertionsRejectedCap);
  }

  static void recordByUidFetch({required bool success}) {
    byUidFetchTotal++;
    if (!success) byUidFetchFailures++;
    _breadcrumb(
      success ? 'creator_by_uid_fetch_total' : 'creator_by_uid_fetch_failures',
      success ? byUidFetchTotal : byUidFetchFailures,
    );
  }

  static void recordStatusEventReceived() {
    statusEventsReceived++;
    _breadcrumb('creator_status_events_received', statusEventsReceived);
  }

  static void _breadcrumb(String name, int value) {
    if (!kReleaseMode) {
      debugPrint('📈 [HOME METRIC] $name=$value');
    }
    if (SentryService.isEnabled) {
      SentryService.addBreadcrumb(
        message: '$name=$value',
        category: 'home.feed',
        data: {'metric': name, 'value': value},
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    socketInsertionsTotal = 0;
    socketInsertionsDeduplicated = 0;
    socketInsertionsRejectedCap = 0;
    byUidFetchTotal = 0;
    byUidFetchFailures = 0;
    statusEventsReceived = 0;
  }
}
