// Defensive decoding for API JSON that may carry Mongo extended shapes
// (`$oid`, `$date`) or plain strings depending on serialization path.

String? readId(dynamic v) {
  if (v == null) return null;
  if (v is String) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
  if (v is int) return v.toString();
  if (v is double) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }
  if (v is Map) {
    final oid = v[r'$oid'];
    if (oid is String && oid.trim().isNotEmpty) return oid.trim();
    if (oid != null) return oid.toString();
  }
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

String readIdString(dynamic v, {String fallback = ''}) {
  final id = readId(v);
  if (id != null && id.isNotEmpty) return id;
  return fallback;
}

DateTime? readDateTime(dynamic v) {
  if (v == null) return null;
  if (v is String) {
    return DateTime.tryParse(v);
  }
  if (v is int) {
    return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
  }
  if (v is Map) {
    final d = v[r'$date'];
    if (d is String) return DateTime.tryParse(d);
    if (d is int) {
      return DateTime.fromMillisecondsSinceEpoch(d, isUtc: true);
    }
    if (d is Map) {
      final nl = d[r'$numberLong'];
      if (nl is String) {
        final ms = int.tryParse(nl);
        if (ms != null) {
          return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
        }
      }
    }
  }
  return null;
}

DateTime readDateTimeWithFallback(dynamic v, {DateTime? fallback}) {
  return readDateTime(v) ?? fallback ?? DateTime.now();
}

/// Returns null for non-scalars (e.g. nested maps) so we do not stringify objects by mistake.
String? readOptionalString(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  if (v is num || v is bool) return v.toString();
  return null;
}

List<String>? readStringList(dynamic raw) {
  if (raw == null) return null;
  if (raw is! List<dynamic>) return null;
  final out = <String>[];
  for (final e in raw) {
    final s = readOptionalString(e);
    if (s != null) out.add(s);
  }
  return out.isEmpty ? null : out;
}

Map<String, dynamic>? readJsonMap(dynamic v) {
  if (v == null) return null;
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}
