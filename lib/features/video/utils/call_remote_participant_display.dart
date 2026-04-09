import 'package:stream_video_flutter/stream_video_flutter.dart';

/// Display fields for the **remote** participant on a call (caller or callee).
class RemoteParticipantDisplay {
  final String primaryName;
  final int? age;
  final String? country;

  const RemoteParticipantDisplay({
    required this.primaryName,
    this.age,
    this.country,
  });

  /// Single line for the dial card title, e.g. `"Alanna, 36"` or `"Alanna"`.
  String get nameLine {
    final n = primaryName.trim();
    final label = n.isEmpty ? 'User' : n;
    if (age != null) return '$label, $age';
    return label;
  }
}

int? _parseAge(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) {
    final t = v.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }
  return null;
}

String? _asTrimmedString(dynamic v) {
  if (v == null) return null;
  if (v is! String) {
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
  final s = v.trim();
  return s.isEmpty ? null : s;
}

Map<String, dynamic>? _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), val));
  }
  return null;
}

String? _countryFromExtra(Map<String, dynamic>? extra) {
  if (extra == null) return null;
  const keys = ['country', 'location', 'region', 'countryName', 'country_name'];
  for (final k in keys) {
    final s = _asTrimmedString(extra[k]);
    if (s != null) return s;
  }
  return null;
}

int? _ageFromExtra(Map<String, dynamic>? extra) {
  if (extra == null) return null;
  const keys = ['age', 'userAge', 'user_age'];
  for (final k in keys) {
    final a = _parseAge(extra[k]);
    if (a != null) return a;
  }
  return null;
}

String? _nameFromUser(dynamic user) {
  if (user == null) return null;
  final n = _asTrimmedString((user as dynamic).name) ??
      _asTrimmedString((user as dynamic).displayName);
  if (n != null) return n;
  final extra = _asMap((user as dynamic).extraData);
  if (extra != null) {
    for (final k in ['displayName', 'username', 'fullName', 'name']) {
      final s = _asTrimmedString(extra[k]);
      if (s != null) return s;
    }
  }
  return null;
}

String _nonEmptyName(String? name, String fallback) {
  final t = name?.trim() ?? '';
  return t.isEmpty ? fallback : t;
}

/// Resolves name, age, and country for the remote participant (not [currentUserId]).
///
/// Order: non-local [members] first, then [createdBy] when that user is remote.
RemoteParticipantDisplay resolveRemoteParticipantDisplay({
  required Call? call,
  required String? currentUserId,
  String fallbackName = 'User',
}) {
  if (call == null) {
    return RemoteParticipantDisplay(primaryName: fallbackName);
  }
  try {
    final dynamic callState = (call as dynamic).state?.value;

    final dynamic members = callState?.members;
    if (members is Iterable) {
      for (final dynamic member in members) {
        final memberId = _asTrimmedString(
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

        final user = (member as dynamic).user;
        final extra = _asMap((member as dynamic).extraData) ??
            _asMap((user as dynamic)?.extraData);
        final name = _nameFromUser(user);
        final age = _ageFromExtra(extra);
        final country = _countryFromExtra(extra);

        return RemoteParticipantDisplay(
          primaryName: _nonEmptyName(name, fallbackName),
          age: age,
          country: country,
        );
      }
    }

    final createdBy = callState?.createdBy;
    final createdById = _asTrimmedString(
      createdBy?.id?.toString() ?? createdBy?.userId?.toString(),
    );
    if (createdById != null &&
        (currentUserId == null ||
            currentUserId.isEmpty ||
            createdById != currentUserId)) {
      final extra = _asMap(createdBy?.extraData);
      final name = _nameFromUser(createdBy) ??
          _asTrimmedString(createdBy?.name?.toString());
      return RemoteParticipantDisplay(
        primaryName: _nonEmptyName(name, fallbackName),
        age: _ageFromExtra(extra),
        country: _countryFromExtra(extra),
      );
    }
  } catch (_) {
    // Best-effort only
  }

  return RemoteParticipantDisplay(primaryName: fallbackName);
}
