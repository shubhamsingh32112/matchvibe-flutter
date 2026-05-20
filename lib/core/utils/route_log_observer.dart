import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../services/sentry_service.dart';

/// Logs navigation events to `debugPrint` (logcat-friendly) and Sentry breadcrumbs.
///
/// Used to detect accidental modal route pushes (dialogs/bottom sheets) during
/// video call teardown, which can manifest as a full-screen gray scrim.
class RouteLogObserver extends NavigatorObserver {
  void _log(String msg) {
    debugPrint('🧭 [NAV] $msg');
  }

  String _routeLabel(Route<dynamic>? route) {
    if (route == null) return 'null';
    final settingsName = route.settings.name;
    return '${route.runtimeType}${settingsName != null ? "(name=$settingsName)" : ""}';
  }

  void _sentryBreadcrumb(String action, Route<dynamic>? route) {
    SentryService.addBreadcrumb(
      category: 'navigation',
      message: '$action ${_routeLabel(route)}',
      level: SentryLevel.info,
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log('push route=${_routeLabel(route)} prev=${_routeLabel(previousRoute)}');
    _sentryBreadcrumb('push', route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log('pop route=${_routeLabel(route)} prev=${_routeLabel(previousRoute)}');
    _sentryBreadcrumb('pop', route);
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log('remove route=${_routeLabel(route)} prev=${_routeLabel(previousRoute)}');
    _sentryBreadcrumb('remove', route);
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _log('replace new=${_routeLabel(newRoute)} old=${_routeLabel(oldRoute)}');
    SentryService.addBreadcrumb(
      category: 'navigation',
      message: 'replace new=${_routeLabel(newRoute)} old=${_routeLabel(oldRoute)}',
      level: SentryLevel.info,
    );
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
