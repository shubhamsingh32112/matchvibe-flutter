/// Cloudflare-based preset avatar registry.
///
/// Calls `GET /images/presets` (added in plan §5.3) and caches the response
/// for the lifetime of the app session.
library;

import '../api/api_client.dart';
import '../images/image_asset_view.dart';

class PresetAvatarEntry {
  PresetAvatarEntry({
    required this.fileName,
    required this.imageId,
    required this.avatarUrls,
  });
  final String fileName;
  final String imageId;
  final AvatarUrls avatarUrls;

  static PresetAvatarEntry? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final fileName = json['fileName']?.toString();
    final imageId = json['imageId']?.toString();
    final urls = AvatarUrls.fromJson(
      json['avatarUrls'] as Map<String, dynamic>?,
    );
    if (fileName == null || imageId == null || urls == null) return null;
    return PresetAvatarEntry(
      fileName: fileName,
      imageId: imageId,
      avatarUrls: urls,
    );
  }
}

class PresetAvatarsResponse {
  PresetAvatarsResponse({
    required this.male,
    required this.female,
    this.defaultImageId,
  });
  final List<PresetAvatarEntry> male;
  final List<PresetAvatarEntry> female;
  final String? defaultImageId;

  PresetAvatarEntry? findByFileName(String fileName, String gender) {
    final list = gender == 'female' ? female : male;
    for (final entry in list) {
      if (entry.fileName == fileName) return entry;
    }
    return null;
  }
}

class ImagePresetsService {
  ImagePresetsService._();
  static final ImagePresetsService instance = ImagePresetsService._();

  /// Canonical preset file names per gender. The backend seed script
  /// (`seed-preset-avatars-cloudflare.ts`) ingests these same names.
  static const String defaultMaleAvatar = 'a2.png';
  static const String defaultFemaleAvatar = 'fa2.png';

  /// Returns the default preset avatar file name for a given gender.
  /// Mirrors the legacy `AvatarUploadService.getDefaultAvatarName` signature
  /// so call-sites can swap in without changes.
  static String getDefaultAvatarName(String? gender) {
    return gender == 'female' ? defaultFemaleAvatar : defaultMaleAvatar;
  }

  /// Returns the preset avatar file names available to a given gender. The
  /// concrete list comes from the cached `/images/presets` response so we
  /// always reflect what the backend actually has; if the cache is empty
  /// (initial load before `load()` resolves), we fall back to the seeded
  /// default so the UI never renders an empty carousel.
  static List<String> getAvailablePresetAvatarNames(String? gender) {
    final cached = instance._cache;
    if (cached == null) {
      return [getDefaultAvatarName(gender)];
    }
    final entries = gender == 'female' ? cached.female : cached.male;
    if (entries.isEmpty) return [getDefaultAvatarName(gender)];
    return entries.map((e) => e.fileName).toList(growable: false);
  }

  /// Resolves the Cloudflare-served preset avatar URL for the carousel.
  /// Uses the `md` (avatarMd, 256x256) variant to stay sharp on tablet
  /// while keeping payload small. Returns the default preset URL if the
  /// requested file name is missing.
  Future<String?> getPresetAvatarUrl({
    required String avatarName,
    required String gender,
  }) async {
    final response = await load();
    final entry = response.findByFileName(avatarName, gender);
    if (entry != null) return entry.avatarUrls.md;
    // Fallback: try the default preset for this gender.
    final fallback = response.findByFileName(
      getDefaultAvatarName(gender),
      gender,
    );
    return fallback?.avatarUrls.md;
  }

  PresetAvatarsResponse? _cache;
  Future<PresetAvatarsResponse>? _pending;

  Future<PresetAvatarsResponse> load() {
    if (_cache != null) return Future.value(_cache);
    if (_pending != null) return _pending!;
    _pending = _fetch();
    return _pending!;
  }

  Future<PresetAvatarsResponse> _fetch() async {
    try {
      final response = await ApiClient().get('/images/presets');
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw Exception('Invalid /images/presets response');
      }
      final data = raw['data'] as Map<String, dynamic>? ?? const {};
      final maleRaw = (data['male'] as List?) ?? const [];
      final femaleRaw = (data['female'] as List?) ?? const [];
      final defaultRaw = data['default'] as Map<String, dynamic>?;
      final result = PresetAvatarsResponse(
        male: maleRaw
            .whereType<Map<String, dynamic>>()
            .map(PresetAvatarEntry.fromJson)
            .whereType<PresetAvatarEntry>()
            .toList(growable: false),
        female: femaleRaw
            .whereType<Map<String, dynamic>>()
            .map(PresetAvatarEntry.fromJson)
            .whereType<PresetAvatarEntry>()
            .toList(growable: false),
        defaultImageId: defaultRaw?['imageId']?.toString(),
      );
      _cache = result;
      _pending = null;
      return result;
    } catch (e) {
      _pending = null;
      rethrow;
    }
  }
}
