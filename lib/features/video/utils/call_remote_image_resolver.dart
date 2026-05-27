import 'package:flutter/foundation.dart' show debugPrint;
import 'package:stream_video_flutter/stream_video_flutter.dart';
import '../../../core/services/sentry_service.dart';

class RemoteImageResolution {
  final String url;
  final String source;

  const RemoteImageResolution({required this.url, required this.source});
}

/// Resolves the remote participant profile image URL for a call.
String? resolveRemoteImageUrl({
  required Call? call,
  required String? currentUserId,
  String? fallbackImageUrl,
  String? fallbackSourceTag,
  bool enableDebugLogs = false,
  String? debugSourceTag,
}) {
  return resolveRemoteImage(
    call: call,
    currentUserId: currentUserId,
    fallbackImageUrl: fallbackImageUrl,
    fallbackSourceTag: fallbackSourceTag,
    enableDebugLogs: enableDebugLogs,
    debugSourceTag: debugSourceTag,
  )?.url;
}

RemoteImageResolution? resolveRemoteImage({
  required Call? call,
  required String? currentUserId,
  String? fallbackImageUrl,
  String? fallbackSourceTag,
  bool enableDebugLogs = false,
  String? debugSourceTag,
}) {
  if (call == null) {
    final fallback = _asNonEmptyString(fallbackImageUrl);
    return fallback == null
        ? null
        : RemoteImageResolution(
            url: fallback,
            source: fallbackSourceTag ?? 'fallback',
          );
  }

  try {
    final dynamic callState = (call as dynamic).state?.value;
    final sourceTag = debugSourceTag ?? 'unknown';
    final debugKey = '$sourceTag:${call.id}';
    final initiatedByRole = _asNonEmptyString(
      _extractFromCallCustom(callState, 'initiatedByRole'),
    )?.toLowerCase();
    final creatorInitiated = initiatedByRole == 'creator';

    RemoteImageResolution? resolveFromCustom() {
      final customImage = _pickDeterministicImage([
        _extractFromCallCustom(callState, 'initiatorImageUrl'),
        _extractFromCallCustom(callState, 'callPhoto'),
        _extractFromCallCustom(callState, 'avatarUrl'),
        _extractFromCallCustom(callState, 'avatar_url'),
        _extractFromCallCustom(callState, 'avatar'),
        _extractFromCallCustom(callState, 'photoUrl'),
        _extractFromCallCustom(callState, 'photoURL'),
        _extractFromCallCustom(callState, 'imageUrl'),
        _extractFromCallCustom(callState, 'image_url'),
        _extractFromCallCustom(callState, 'image'),
      ]);
      if (customImage == null) return null;
      _emitResolutionTelemetry(
        source: 'custom',
        url: customImage,
        debugKey: debugKey,
        sourceTag: sourceTag,
        callId: call.id,
        enableDebugLogs: enableDebugLogs,
      );
      return RemoteImageResolution(url: customImage, source: 'custom');
    }

    if (creatorInitiated) {
      final custom = resolveFromCustom();
      if (custom != null) return custom;
    }

    final dynamic members = callState?.members;
    if (members is Iterable) {
      for (final dynamic member in members) {
        final memberId = _asNonEmptyString(
          (member as dynamic).userId ??
              (member as dynamic).user?.id ??
              (member as dynamic).user?.userId,
        );
        if (memberId == null) continue;
        if (currentUserId != null &&
            currentUserId.isNotEmpty &&
            memberId == currentUserId) {
          continue;
        }

        final imageUrl = _pickDeterministicImage([
          (member as dynamic).user?.image,
          (member as dynamic).user?.imageUrl,
          (member as dynamic).image,
          _extractImageFromExtraData((member as dynamic).user?.extraData),
          _extractImageFromExtraData((member as dynamic).extraData),
        ]);
        if (imageUrl != null) {
          _emitResolutionTelemetry(
            source: 'member',
            url: imageUrl,
            debugKey: debugKey,
            sourceTag: sourceTag,
            callId: call.id,
            enableDebugLogs: enableDebugLogs,
          );
          return RemoteImageResolution(url: imageUrl, source: 'member');
        }
      }
    }

    final createdByImage = _pickDeterministicImage([
      callState?.createdBy?.image,
      callState?.createdBy?.imageUrl,
      _extractImageFromExtraData(callState?.createdBy?.extraData),
    ]);
    final createdById = _asNonEmptyString(
      callState?.createdBy?.id ?? callState?.createdBy?.userId,
    );
    if (createdById != null &&
        (currentUserId == null ||
            currentUserId.isEmpty ||
            createdById != currentUserId) &&
        createdByImage != null) {
      _emitResolutionTelemetry(
        source: 'createdBy',
        url: createdByImage,
        debugKey: debugKey,
        sourceTag: sourceTag,
        callId: call.id,
        enableDebugLogs: enableDebugLogs,
      );
      return RemoteImageResolution(url: createdByImage, source: 'createdBy');
    }

    if (!creatorInitiated) {
      final custom = resolveFromCustom();
      if (custom != null) return custom;
    }

    final fallback = _asNonEmptyString(fallbackImageUrl);
    if (fallback != null) {
      final fallbackSource = fallbackSourceTag ?? 'fallback';
      _emitResolutionTelemetry(
        source: fallbackSource,
        url: fallback,
        debugKey: debugKey,
        sourceTag: sourceTag,
        callId: call.id,
        enableDebugLogs: enableDebugLogs,
      );
      return RemoteImageResolution(url: fallback, source: fallbackSource);
    }

    _debugDumpOnce(
      enable: enableDebugLogs,
      key: debugKey,
      lines: [
        '⚠️ [CALL BG][$sourceTag] No remote image found for call ${call.id}',
        '   currentUserId=$currentUserId, createdById=$createdById, createdByImage=$createdByImage',
        '   membersCount=${members is Iterable ? members.length : 0}',
        '   createdBy.extraData keys: ${_mapKeys(callState?.createdBy?.extraData)}',
      ],
    );
  } catch (_) {
    // Best-effort avatar resolution; UI fallback handles failures.
  }

  final fallback = _asNonEmptyString(fallbackImageUrl);
  return fallback == null
      ? null
      : RemoteImageResolution(
          url: fallback,
          source: fallbackSourceTag ?? 'fallback',
        );
}

/// Firebase UID of the **remote** participant (not [currentUserId]), if known.
String? resolveRemoteParticipantFirebaseUid({
  required Call? call,
  required String? currentUserId,
}) {
  if (call == null) return null;
  try {
    final dynamic callState = (call as dynamic).state?.value;
    final dynamic members = callState?.members;
    if (members is Iterable) {
      for (final dynamic member in members) {
        final memberId = _asNonEmptyString(
          (member as dynamic).userId ??
              (member as dynamic).user?.id ??
              (member as dynamic).user?.userId,
        );
        if (memberId == null) continue;
        if (currentUserId != null &&
            currentUserId.isNotEmpty &&
            memberId == currentUserId) {
          continue;
        }
        return memberId;
      }
    }
    final createdById = _asNonEmptyString(
      callState?.createdBy?.id?.toString() ??
          callState?.createdBy?.userId?.toString(),
    );
    if (createdById != null &&
        (currentUserId == null ||
            currentUserId.isEmpty ||
            createdById != currentUserId)) {
      return createdById;
    }
  } catch (_) {}
  return null;
}

String? _extractImageFromExtraData(dynamic extraData) {
  if (extraData is! Map) return null;
  return _pickDeterministicImage([
    extraData['initiatorImageUrl'],
    extraData['callPhoto'],
    extraData['call_photo'],
    extraData['avatarUrl'],
    extraData['avatar_url'],
    extraData['avatar'],
    extraData['imageUrl'],
    extraData['image_url'],
    extraData['image'],
    extraData['profileImage'],
    extraData['profile_image'],
    extraData['photoURL'],
    extraData['photoUrl'],
  ]);
}

dynamic _extractFromCallCustom(dynamic callState, String key) {
  try {
    final dynamic custom = (callState as dynamic)?.custom;
    if (custom is Map) return custom[key];
  } catch (_) {}
  try {
    final dynamic customData = (callState as dynamic)?.customData;
    if (customData is Map) return customData[key];
  } catch (_) {}
  try {
    final dynamic extraData = (callState as dynamic)?.extraData;
    if (extraData is Map) return extraData[key];
  } catch (_) {}
  return null;
}

String? _asNonEmptyString(dynamic value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

final Set<String> _debugLoggedCallKeys = <String>{};
final Set<String> _resolutionBreadcrumbKeys = <String>{};

void _debugDumpOnce({
  required bool enable,
  required String key,
  required List<String> lines,
}) {
  if (!enable) return;
  if (_debugLoggedCallKeys.contains(key)) return;
  _debugLoggedCallKeys.add(key);
  for (final line in lines) {
    debugPrint(line);
  }
}

String _mapKeys(dynamic value) {
  if (value is Map) {
    return value.keys.map((k) => k.toString()).join(', ');
  }
  return 'none';
}

String? _pickDeterministicImage(List<dynamic> candidates) {
  String? firstNonEmpty;
  for (final candidate in candidates) {
    final parsed = _asNonEmptyString(candidate);
    if (parsed == null) continue;
    firstNonEmpty ??= parsed;
    if (_isCloudflareDeliveryUrl(parsed)) {
      return parsed;
    }
  }
  return firstNonEmpty;
}

bool _isCloudflareDeliveryUrl(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  return host.contains('imagedelivery.net');
}

void _emitResolutionTelemetry({
  required String source,
  required String url,
  required String debugKey,
  required String sourceTag,
  required String callId,
  required bool enableDebugLogs,
}) {
  final key = '$debugKey|$source|$url';
  if (_resolutionBreadcrumbKeys.contains(key)) return;
  _resolutionBreadcrumbKeys.add(key);

  SentryService.addBreadcrumb(
    category: 'call.avatar.resolve',
    message: 'incoming_avatar_source_selected',
    data: {
      'call_id': callId,
      'source': source,
      'source_tag': sourceTag,
      'url_host': Uri.tryParse(url)?.host ?? '',
    },
  );
  if (enableDebugLogs) {
    debugPrint('✅ [CALL BG][$sourceTag] Resolved image from $source: $url');
  }
}
