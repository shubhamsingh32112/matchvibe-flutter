import 'package:flutter/foundation.dart' show debugPrint;

import '../../../core/api/api_client.dart';
import '../../../shared/models/creator_model.dart';

class AvatarLookupResult {
  final String url;
  final String source;

  const AvatarLookupResult({required this.url, required this.source});
}

class _AvatarLookupCacheEntry {
  final String? value;
  final String source;
  final DateTime expiresAt;

  const _AvatarLookupCacheEntry({
    required this.value,
    required this.source,
    required this.expiresAt,
  });
}

const Duration _avatarCacheSuccessTtl = Duration(minutes: 20);
const Duration _avatarCacheNullTtl = Duration(seconds: 20);
final Map<String, _AvatarLookupCacheEntry> _avatarLookupCache =
    <String, _AvatarLookupCacheEntry>{};

/// Extracts caller Firebase UID from deterministic call IDs:
/// `<callerFirebaseUid>_<creatorMongoId>_<timestamp>`.
String? extractCallerFirebaseUidFromCallId(String? callId) {
  if (callId == null || callId.isEmpty) return null;
  final trimmed = callId.trim();
  if (trimmed.isEmpty) return null;

  final parts = trimmed.split('_');
  if (parts.length < 3) return null;

  // Parse from right to support firebase UIDs that may contain underscores.
  final tsPart = parts.last.trim();
  final creatorMongoIdPart = parts[parts.length - 2].trim();
  final initiatorParts = parts.sublist(0, parts.length - 2);
  final initiator = initiatorParts.join('_').trim();

  final ts = int.tryParse(tsPart);
  final looksLikeCreatorMongoId = RegExp(
    r'^[a-fA-F0-9]{24}$',
  ).hasMatch(creatorMongoIdPart);
  if (ts == null || !looksLikeCreatorMongoId || initiator.isEmpty) {
    // Fallback to legacy parser behavior for unexpected call-id shapes.
    final idx = trimmed.indexOf('_');
    if (idx <= 0) return null;
    final parsed = trimmed.substring(0, idx).trim();
    return parsed.isEmpty ? null : parsed;
  }
  return initiator;
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
  bool forceRefresh = false,
}) async {
  final uid = _normalize(remoteFirebaseUid);
  final username = _normalize(remoteUsername);
  final cacheKey = 'user:${uid ?? ''}|${username ?? ''}';
  final cached = _readCache(cacheKey, forceRefresh: forceRefresh);
  if (cached != null) {
    return cached.value;
  }

  if ((uid == null || uid.isEmpty) && (username == null || username.isEmpty)) {
    _writeCache(cacheKey, value: null, source: 'empty_input');
    return null;
  }

  try {
    final response = await ApiClient().get('/user/list');
    final usersData = response.data?['data']?['users'];
    if (usersData is! List) {
      _writeCache(cacheKey, value: null, source: 'user_list_empty');
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
      final usernameMatched =
          username != null &&
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
        _writeCache(cacheKey, value: resolved, source: 'rest_lookup:user_list');
        return resolved;
      }
    }
  } catch (e) {
    debugPrint(
      '❌ [CALL BG][${debugSourceTag ?? 'lookup'}] /user/list lookup failed: $e',
    );
  }

  _writeCache(cacheKey, value: null, source: 'rest_lookup:user_list_miss');
  return null;
}

/// O(1) user avatar lookup via [GET /user/by-firebase-uid/:uid].
Future<String?> lookupAvatarFromUserByFirebaseUid({
  required String remoteFirebaseUid,
  String? debugSourceTag,
  bool forceRefresh = false,
}) async {
  final uid = remoteFirebaseUid.trim();
  if (uid.isEmpty) return null;

  final cacheKey = 'user_uid:$uid';
  final cached = _readCache(cacheKey, forceRefresh: forceRefresh);
  if (cached != null) {
    return cached.value;
  }

  try {
    final response = await ApiClient().get(
      '/user/by-firebase-uid/${Uri.encodeComponent(uid)}',
    );
    final row = response.data?['data']?['user'];
    if (row is Map) {
      final photo = resolveAvatarUrlFromRow(Map<String, dynamic>.from(row));
      if (photo != null && photo.isNotEmpty) {
        debugPrint(
          '✅ [CALL BG][${debugSourceTag ?? 'lookup'}] Avatar from /user/by-firebase-uid: $photo',
        );
        _writeCache(
          cacheKey,
          value: photo,
          source: 'rest_lookup:user_by_firebase_uid',
        );
        return photo;
      }
    }
  } catch (e) {
    debugPrint(
      '❌ [CALL BG][${debugSourceTag ?? 'lookup'}] /user/by-firebase-uid failed: $e',
    );
  }

  _writeCache(
    cacheKey,
    value: null,
    source: 'rest_lookup:user_by_firebase_uid_miss',
  );
  return null;
}

/// O(1) creator avatar lookup via [GET /creator/by-firebase-uid/:uid].
Future<String?> lookupAvatarFromCreatorsByFirebaseUid({
  required String remoteFirebaseUid,
  String? debugSourceTag,
  bool forceRefresh = false,
}) async {
  final uid = remoteFirebaseUid.trim();
  if (uid.isEmpty) return null;

  final cacheKey = 'creator_uid:$uid';
  final cached = _readCache(cacheKey, forceRefresh: forceRefresh);
  if (cached != null) {
    return cached.value;
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
        _writeCache(
          cacheKey,
          value: photo,
          source: 'rest_lookup:creator_by_firebase_uid',
        );
        return photo;
      }
    }
  } catch (e) {
    debugPrint(
      '❌ [CALL BG][${debugSourceTag ?? 'lookup'}] /creator/by-firebase-uid failed: $e',
    );
  }

  _writeCache(
    cacheKey,
    value: null,
    source: 'rest_lookup:creator_by_firebase_uid_miss',
  );
  return null;
}

/// Scans the first page of [GET /creator/feed] for a matching creator avatar.
Future<String?> lookupAvatarFromCreatorFeedPage({
  String? remoteFirebaseUid,
  String? remoteUsername,
  String? debugSourceTag,
  bool forceRefresh = false,
}) async {
  final uidNorm = _normalize(remoteFirebaseUid);
  final usernameNorm = _normalize(remoteUsername);
  if ((uidNorm == null || uidNorm.isEmpty) &&
      (usernameNorm == null || usernameNorm.isEmpty)) {
    return null;
  }

  final cacheKey = 'creator_feed:${uidNorm ?? ''}|${usernameNorm ?? ''}';
  final cached = _readCache(cacheKey, forceRefresh: forceRefresh);
  if (cached != null) {
    return cached.value;
  }

  try {
    final response = await ApiClient().get('/creator/feed?page=1&limit=50');
    final creatorsData = response.data?['data']?['creators'];
    if (creatorsData is! List) {
      _writeCache(cacheKey, value: null, source: 'creator_feed_empty');
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
        _writeCache(cacheKey, value: photo, source: 'rest_lookup:creator_feed');
        return photo;
      }
    }
  } catch (e) {
    debugPrint(
      '❌ [CALL BG][${debugSourceTag ?? 'lookup'}] /creator/feed lookup failed: $e',
    );
  }

  _writeCache(cacheKey, value: null, source: 'rest_lookup:creator_feed_miss');
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
  bool forceRefresh = false,
  bool incomingRing = false,
}) async {
  final result = await lookupIncomingCallerAvatarResult(
    calleeRole: calleeRole,
    remoteFirebaseUid: remoteFirebaseUid,
    remoteUsername: remoteUsername,
    debugSourceTag: debugSourceTag,
    cachedCreators: cachedCreators,
    forceRefresh: forceRefresh,
    incomingRing: incomingRing,
  );
  return result?.url;
}

Future<AvatarLookupResult?> lookupIncomingCallerAvatarResult({
  required String? calleeRole,
  String? remoteFirebaseUid,
  String? remoteUsername,
  String? debugSourceTag,
  List<CreatorModel>? cachedCreators,
  bool forceRefresh = false,
  bool incomingRing = false,
}) async {
  final role = (calleeRole ?? '').trim().toLowerCase();
  final isCreatorCallee = role == 'creator' || role == 'admin';
  final shouldForceRefresh = forceRefresh || incomingRing;

  if (isCreatorCallee) {
    final uid = remoteFirebaseUid?.trim();
    if (uid != null && uid.isNotEmpty) {
      final fromUserByUid = await lookupAvatarFromUserByFirebaseUid(
        remoteFirebaseUid: uid,
        debugSourceTag: debugSourceTag,
        forceRefresh: shouldForceRefresh,
      );
      if (fromUserByUid != null && fromUserByUid.isNotEmpty) {
        return AvatarLookupResult(
          url: fromUserByUid,
          source: 'rest_lookup:user_by_firebase_uid',
        );
      }
    }

    final fromUsers = await lookupAvatarFromUserList(
      remoteFirebaseUid: remoteFirebaseUid,
      remoteUsername: remoteUsername,
      debugSourceTag: debugSourceTag,
      forceRefresh: shouldForceRefresh,
    );
    if (fromUsers != null && fromUsers.isNotEmpty) {
      return AvatarLookupResult(
        url: fromUsers,
        source: 'rest_lookup:user_list',
      );
    }
  } else {
    final uid = remoteFirebaseUid?.trim();
    if (uid != null && uid.isNotEmpty) {
      final fromUid = await lookupAvatarFromCreatorsByFirebaseUid(
        remoteFirebaseUid: uid,
        debugSourceTag: debugSourceTag,
        forceRefresh: shouldForceRefresh,
      );
      if (fromUid != null && fromUid.isNotEmpty) {
        return AvatarLookupResult(
          url: fromUid,
          source: 'rest_lookup:creator_by_firebase_uid',
        );
      }
    }

    final fromFeed = await lookupAvatarFromCreatorFeedPage(
      remoteFirebaseUid: remoteFirebaseUid,
      remoteUsername: remoteUsername,
      debugSourceTag: debugSourceTag,
      forceRefresh: shouldForceRefresh,
    );
    if (fromFeed != null && fromFeed.isNotEmpty) {
      return AvatarLookupResult(
        url: fromFeed,
        source: 'rest_lookup:creator_feed',
      );
    }

    final fromCache = _lookupAvatarFromCachedCreators(
      cachedCreators: cachedCreators,
      remoteFirebaseUid: remoteFirebaseUid,
      remoteUsername: remoteUsername,
    );
    if (fromCache != null && fromCache.isNotEmpty) {
      return AvatarLookupResult(url: fromCache, source: 'cache:creator_list');
    }
  }

  // Creator callee: try creator endpoints if user list missed (edge case).
  if (isCreatorCallee) {
    final uid = remoteFirebaseUid?.trim();
    if (uid != null && uid.isNotEmpty) {
      final fromUid = await lookupAvatarFromCreatorsByFirebaseUid(
        remoteFirebaseUid: uid,
        debugSourceTag: debugSourceTag,
        forceRefresh: shouldForceRefresh,
      );
      if (fromUid != null && fromUid.isNotEmpty) {
        return AvatarLookupResult(
          url: fromUid,
          source: 'rest_lookup:creator_by_firebase_uid',
        );
      }
    }
    final fromFeed = await lookupAvatarFromCreatorFeedPage(
      remoteFirebaseUid: remoteFirebaseUid,
      remoteUsername: remoteUsername,
      debugSourceTag: debugSourceTag,
      forceRefresh: shouldForceRefresh,
    );
    if (fromFeed != null && fromFeed.isNotEmpty) {
      return AvatarLookupResult(
        url: fromFeed,
        source: 'rest_lookup:creator_feed',
      );
    }
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
    final idMatched =
        uidNorm != null &&
        uidNorm.isNotEmpty &&
        creatorUid != null &&
        creatorUid == uidNorm;
    final nameMatched =
        usernameNorm != null &&
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
  final idMatched =
      remoteFirebaseUid != null &&
      remoteFirebaseUid.isNotEmpty &&
      creatorFirebaseUid != null &&
      creatorFirebaseUid == remoteFirebaseUid;
  final nameMatched =
      remoteUsername != null &&
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

_AvatarLookupCacheEntry? _readCache(String key, {bool forceRefresh = false}) {
  if (forceRefresh) return null;
  final entry = _avatarLookupCache[key];
  if (entry == null) return null;
  if (DateTime.now().isAfter(entry.expiresAt)) {
    _avatarLookupCache.remove(key);
    return null;
  }
  return entry;
}

void _writeCache(String key, {required String? value, required String source}) {
  final ttl = value == null ? _avatarCacheNullTtl : _avatarCacheSuccessTtl;
  _avatarLookupCache[key] = _AvatarLookupCacheEntry(
    value: value,
    source: source,
    expiresAt: DateTime.now().add(ttl),
  );
}
