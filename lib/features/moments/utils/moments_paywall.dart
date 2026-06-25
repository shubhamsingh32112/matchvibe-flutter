import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/moments_api_service.dart';
import '../widgets/moments_premium_bottom_sheet.dart';

Future<void>? _activeSheet;

/// Single entry point for the Moments Premium paywall bottom sheet.
Future<void> showMomentsPremiumSheet(
  BuildContext context,
  WidgetRef ref, {
  String source = 'unknown',
  String? momentId,
}) async {
  if (_activeSheet != null) {
    return _activeSheet;
  }
  _activeSheet = _openSheet(context, ref, source: source, momentId: momentId);
  try {
    await _activeSheet;
  } finally {
    _activeSheet = null;
  }
}

Future<void> _openSheet(
  BuildContext context,
  WidgetRef ref, {
  required String source,
  String? momentId,
}) async {
  unawaited(
    MomentsApiService().recordPaywallShown(source: source, momentId: momentId),
  );
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => MomentsPremiumBottomSheet(parentRef: ref),
  );
}
