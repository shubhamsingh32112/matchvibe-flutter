import 'package:flutter/foundation.dart' show debugPrint;

import '../../../core/api/api_client.dart';

final Map<String, String?> _avatarLookupCache = <String, String?>{};

/// Extracts caller Firebase UID from deterministic call IDs:
/// `<callerFirebaseUid>_<creatorMongoId>_<timestamp>`.
String? extractCallerFirebaseUidFromCallId(String? callId) {
  if (callId == null || callId.isEmpty) return null;
  final idx = callId.indexOf('_');
  if (idx <= 0) return null;
  final parsed = callId.substring(0, idx).trim();
  return parsed.isEmpty ? null : parsed;
}

/// Best-effort lookup of a user's avatar from `/user/list`.
///
/// This is a fallback path for creator-side incoming calls where Stream call
/// metadata can miss `image/imageUrl` for the remote caller.
Future<String?> lookupAvatarFromUserList({
  String? remoteFirebaseUid,
  String? remoteUsername,
  String? debugSourceTag,
}) async {
  final uid = _normalize(remoteFirebaseUid);
  final username = _normalize(remoteUsername);
  final cacheKey = '${uid ?? ''}|${username ?? ''}';
  if (_avatarLookupCache.containsKey(cacheKey)) {
    return _avatarLookupCache[cacheKey];
  }

  if ((uid == null || uid.isEmpty) && (username == null || username.isEmpty)) {
    _avatarLookupCache[cacheKey] = null;
    return null;
  }

  try {
    final response = await ApiClient().get('/user/list');
    final usersData = response.data?['data']?['users'];
    if (usersData is! List) {
      _avatarLookupCache[cacheKey] = null;
      return null;
    }

    for (final item in usersData) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);

      final rowFirebaseCandidates = <String?>[
        _asString(row['firebaseUid']),
        _asString(row['firebaseUID']),
        _asString(row['uid']),
        _asString(row['streamUserId']),
        _asString(row['streamUserID']),
        _asString(row['userFirebaseUid']),
      ].map(_normalize);

      final rowUsernameCandidates = <String?>[
        _asString(row['username']),
        _asString(row['name']),
        _asString(row['displayName']),
      ].map(_normalize);

      final idMatched =
          uid != null && uid.isNotEmpty && rowFirebaseCandidates.contains(uid);
      final usernameMatched = username != null &&
          username.isNotEmpty &&
          rowUsernameCandidates.contains(username);

      if (!idMatched && !usernameMatched) continue;

      final avatar = _asString(row['avatar']) ??
          _asString(row['photo']) ??
          _asString(row['image']) ??
          _asString(row['imageUrl']) ??
          _asString(row['photoUrl']) ??
          _asString(row['photoURL']);

      if (avatar != null && avatar.trim().isNotEmpty) {
        final resolved = avatar.trim();
        debugPrint(
          '✅ [CALL BG][${debugSourceTag ?? 'lookup'}] Avatar matched from /user/list'
          ' (uidMatch=$idMatched, usernameMatch=$usernameMatched): $resolved',
        );
        _avatarLookupCache[cacheKey] = resolved;
        return resolved;
      }
    }
  } catch (e) {
    debugPrint(
      '❌ [CALL BG][${debugSourceTag ?? 'lookup'}] /user/list lookup failed: $e',
    );
  }

  _avatarLookupCache[cacheKey] = null;
  return null;
}

String? _asString(dynamic value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _normalize(String? value) {
  if (value == null) return null;
  final trimmed = value.trim().toLowerCase();
  return trimmed.isEmpty ? null : trimmed;
}
