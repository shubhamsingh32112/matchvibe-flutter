import 'package:flutter/foundation.dart' show debugPrint;
import 'package:stream_video_flutter/stream_video_flutter.dart';

/// Resolves the remote participant profile image URL for a call.
///
/// Uses member records first (most reliable before connect), then falls back
/// to `createdBy` when applicable.
String? resolveRemoteImageUrl({
  required Call? call,
  required String? currentUserId,
  String? fallbackImageUrl,
  bool enableDebugLogs = false,
  String? debugSourceTag,
}) {
  if (call == null) return _asNonEmptyString(fallbackImageUrl);

  try {
    final dynamic callState = (call as dynamic).state?.value;
    final sourceTag = debugSourceTag ?? 'unknown';
    final debugKey = '$sourceTag:${call.id}';

    // Prefer member records because they contain both participants before connect.
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

        final imageUrl = _asNonEmptyString(
          (member as dynamic).user?.image ??
              (member as dynamic).user?.imageUrl ??
              (member as dynamic).image ??
              _extractImageFromExtraData((member as dynamic).user?.extraData) ??
              _extractImageFromExtraData((member as dynamic).extraData),
        );
        if (imageUrl != null) {
          _debugDumpOnce(
            enable: enableDebugLogs,
            key: debugKey,
            lines: [
              '✅ [CALL BG][$sourceTag] Resolved image from members: $imageUrl',
            ],
          );
          return imageUrl;
        }
      }
    }

    final createdByImage = _asNonEmptyString(
      callState?.createdBy?.image ??
          callState?.createdBy?.imageUrl ??
          _extractImageFromExtraData(callState?.createdBy?.extraData),
    );
    final createdById = _asNonEmptyString(
      callState?.createdBy?.id ?? callState?.createdBy?.userId,
    );
    if (createdById != null &&
        (currentUserId == null ||
            currentUserId.isEmpty ||
            createdById != currentUserId)) {
      if (createdByImage != null) {
        _debugDumpOnce(
          enable: enableDebugLogs,
          key: debugKey,
          lines: [
            '✅ [CALL BG][$sourceTag] Resolved image from createdBy: $createdByImage',
          ],
        );
        return createdByImage;
      }
    }

    final fallback = _asNonEmptyString(fallbackImageUrl);
    if (fallback != null) {
      _debugDumpOnce(
        enable: enableDebugLogs,
        key: debugKey,
        lines: [
          '⚠️ [CALL BG][$sourceTag] Using app-model fallback image: $fallback',
        ],
      );
      return fallback;
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

  return _asNonEmptyString(fallbackImageUrl);
}

String? _extractImageFromExtraData(dynamic extraData) {
  if (extraData is! Map) return null;
  const keys = [
    'image',
    'imageUrl',
    'image_url',
    'avatar',
    'avatarUrl',
    'avatar_url',
    'profileImage',
    'profile_image',
    'photoURL',
    'photoUrl',
  ];
  for (final key in keys) {
    final value = extraData[key];
    final parsed = _asNonEmptyString(value);
    if (parsed != null) return parsed;
  }
  return null;
}

String? _asNonEmptyString(dynamic value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

final Set<String> _debugLoggedCallKeys = <String>{};

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
