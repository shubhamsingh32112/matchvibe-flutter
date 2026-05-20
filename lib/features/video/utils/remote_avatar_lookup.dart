import 'package:flutter/foundation.dart' show debugPrint;

import '../../../core/api/api_client.dart';
import '../../../shared/models/creator_model.dart';

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

/// Resolves a display URL from API row payloads: Cloudflare `avatar` /
/// `avatarAsset` objects (preferred) or legacy flat URL strings.
String? resolveAvatarUrlFromRow(Map<String, dynamic> row) {
  for (final key in ['avatar', 'avatarAsset']) {
    final nested = row[key];
    if (nested is Map) {
      final urls = nested['avatarUrls'];
      if (urls is Map) {
        for (final variant in ['callPhoto', 'md', 'sm', 'xs', 'feedTile']) {
          final url = _asString(urls[variant]);
          if (url != null) return url;
        }
      }
    }
  }
  return _asString(row['avatar']) ??
      _asString(row['photo']) ??
      _asString(row['image']) ??
      _asString(row['imageUrl']) ??
      _asString(row['photoUrl']) ??
      _asString(row['photoURL']);
}

/// Avatar URL from an in-memory [CreatorModel] (feed cache).
String? avatarUrlFromCreatorModel(CreatorModel creator) {
  final urls = creator.avatar?.avatarUrls;
  if (urls != null) {
    final callPhoto = urls.callPhoto.trim();
    if (callPhoto.isNotEmpty) return callPhoto;
    final md = urls.md.trim();
    if (md.isNotEmpty) return md;
  }
  final feedTile = creator.feedTileUrl?.trim();
  return feedTile != null && feedTile.isNotEmpty ? feedTile : null;
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
  final cacheKey = 'user:${uid ?? ''}|${username ?? ''}';
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

      final avatar = resolveAvatarUrlFromRow(row);

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

/// O(1) creator avatar lookup via [GET /creator/by-firebase-uid/:uid].
Future<String?> lookupAvatarFromCreatorsByFirebaseUid({
  required String remoteFirebaseUid,
  String? debugSourceTag,
}) async {
  final uid = remoteFirebaseUid.trim();
  if (uid.isEmpty) return null;

  final cacheKey = 'creator_uid:$uid';
  if (_avatarLookupCache.containsKey(cacheKey)) {
    return _avatarLookupCache[cacheKey];
  }

  try {
    final response = await ApiClient().get(
      '/creator/by-firebase-uid/${Uri.encodeComponent(uid)}',
    );
    final creator = response.data?['data']?['creator'];
    if (creator is Map) {
      final photo = resolveAvatarUrlFromRow(Map<String, dynamic>.from(creator));
      if (photo != null && photo.isNotEmpty) {
        debugPrint(
          '✅ [CALL BG][${debugSourceTag ?? 'lookup'}] Avatar from /creator/by-firebase-uid: $photo',
        );
        _avatarLookupCache[cacheKey] = photo;
        return photo;
      }
    }
  } catch (e) {
    debugPrint(
      '❌ [CALL BG][${debugSourceTag ?? 'lookup'}] /creator/by-firebase-uid failed: $e',
    );
  }

  _avatarLookupCache[cacheKey] = null;
  return null;
}

/// Scans the first page of [GET /creator/feed] for a matching creator avatar.
Future<String?> lookupAvatarFromCreatorFeedPage({
  String? remoteFirebaseUid,
  String? remoteUsername,
  String? debugSourceTag,
}) async {
  final uidNorm = _normalize(remoteFirebaseUid);
  final usernameNorm = _normalize(remoteUsername);
  if ((uidNorm == null || uidNorm.isEmpty) &&
      (usernameNorm == null || usernameNorm.isEmpty)) {
    return null;
  }

  final cacheKey = 'creator_feed:${uidNorm ?? ''}|${usernameNorm ?? ''}';
  if (_avatarLookupCache.containsKey(cacheKey)) {
    return _avatarLookupCache[cacheKey];
  }

  try {
    final response = await ApiClient().get('/creator/feed?page=1&limit=50');
    final creatorsData = response.data?['data']?['creators'];
    if (creatorsData is! List) {
      _avatarLookupCache[cacheKey] = null;
      return null;
    }

    for (final item in creatorsData) {
      if (item is! Map) continue;
      final creator = Map<String, dynamic>.from(item);
      if (!_creatorRowMatches(
        creator,
        remoteFirebaseUid: uidNorm,
        remoteUsername: usernameNorm,
      )) {
        continue;
      }
      final photo = resolveAvatarUrlFromRow(creator);
      if (photo != null && photo.isNotEmpty) {
        debugPrint(
          '✅ [CALL BG][${debugSourceTag ?? 'lookup'}] Avatar from /creator/feed: $photo',
        );
        _avatarLookupCache[cacheKey] = photo;
        return photo;
      }
    }
  } catch (e) {
    debugPrint(
      '❌ [CALL BG][${debugSourceTag ?? 'lookup'}] /creator/feed lookup failed: $e',
    );
  }

  _avatarLookupCache[cacheKey] = null;
  return null;
}

/// Role-aware REST fallback for incoming-call avatar prefetch.
///
/// - Creator callee (user called): `/user/list` then creator endpoints.
/// - User callee (creator called): creator by-uid, feed scan, optional cache.
Future<String?> lookupIncomingCallerAvatar({
  required String? calleeRole,
  String? remoteFirebaseUid,
  String? remoteUsername,
  String? debugSourceTag,
  List<CreatorModel>? cachedCreators,
}) async {
  final role = (calleeRole ?? '').trim().toLowerCase();
  final isCreatorCallee = role == 'creator' || role == 'admin';

  if (isCreatorCallee) {
    final fromUsers = await lookupAvatarFromUserList(
      remoteFirebaseUid: remoteFirebaseUid,
      remoteUsername: remoteUsername,
      debugSourceTag: debugSourceTag,
    );
    if (fromUsers != null && fromUsers.isNotEmpty) return fromUsers;
  } else {
    final fromCache = _lookupAvatarFromCachedCreators(
      cachedCreators: cachedCreators,
      remoteFirebaseUid: remoteFirebaseUid,
      remoteUsername: remoteUsername,
    );
    if (fromCache != null && fromCache.isNotEmpty) return fromCache;

    final uid = remoteFirebaseUid?.trim();
    if (uid != null && uid.isNotEmpty) {
      final fromUid = await lookupAvatarFromCreatorsByFirebaseUid(
        remoteFirebaseUid: uid,
        debugSourceTag: debugSourceTag,
      );
      if (fromUid != null && fromUid.isNotEmpty) return fromUid;
    }

    final fromFeed = await lookupAvatarFromCreatorFeedPage(
      remoteFirebaseUid: remoteFirebaseUid,
      remoteUsername: remoteUsername,
      debugSourceTag: debugSourceTag,
    );
    if (fromFeed != null && fromFeed.isNotEmpty) return fromFeed;
  }

  // Creator callee: try creator endpoints if user list missed (edge case).
  if (isCreatorCallee) {
    final uid = remoteFirebaseUid?.trim();
    if (uid != null && uid.isNotEmpty) {
      final fromUid = await lookupAvatarFromCreatorsByFirebaseUid(
        remoteFirebaseUid: uid,
        debugSourceTag: debugSourceTag,
      );
      if (fromUid != null && fromUid.isNotEmpty) return fromUid;
    }
    return lookupAvatarFromCreatorFeedPage(
      remoteFirebaseUid: remoteFirebaseUid,
      remoteUsername: remoteUsername,
      debugSourceTag: debugSourceTag,
    );
  }

  return null;
}

String? _lookupAvatarFromCachedCreators({
  List<CreatorModel>? cachedCreators,
  String? remoteFirebaseUid,
  String? remoteUsername,
}) {
  if (cachedCreators == null || cachedCreators.isEmpty) return null;
  final uidNorm = _normalize(remoteFirebaseUid);
  final usernameNorm = _normalize(remoteUsername);

  for (final c in cachedCreators) {
    final creatorUid = _normalize(c.firebaseUid);
    final idMatched = uidNorm != null &&
        uidNorm.isNotEmpty &&
        creatorUid != null &&
        creatorUid == uidNorm;
    final nameMatched = usernameNorm != null &&
        usernameNorm.isNotEmpty &&
        c.name.trim().toLowerCase() == usernameNorm;
    if (!idMatched && !nameMatched) continue;

    final url = avatarUrlFromCreatorModel(c);
    if (url != null && url.isNotEmpty) return url;
  }
  return null;
}

bool _creatorRowMatches(
  Map<String, dynamic> creator, {
  String? remoteFirebaseUid,
  String? remoteUsername,
}) {
  final creatorFirebaseUid = _normalize(creator['firebaseUid']?.toString());
  final creatorName = _normalize(creator['name']?.toString());
  final idMatched = remoteFirebaseUid != null &&
      remoteFirebaseUid.isNotEmpty &&
      creatorFirebaseUid != null &&
      creatorFirebaseUid == remoteFirebaseUid;
  final nameMatched = remoteUsername != null &&
      remoteUsername.isNotEmpty &&
      creatorName != null &&
      creatorName == remoteUsername;
  return idMatched || nameMatched;
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
