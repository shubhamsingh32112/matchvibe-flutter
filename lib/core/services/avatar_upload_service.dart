import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service to upload avatar images to Firebase Storage
/// and retrieve their public download URLs.
///
/// Supports:
/// - Premade avatar assets (bundled in the app)
/// - Gallery images (user‑picked photos)
class AvatarUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final Map<String, String> _presetUrlCache = {};
  static const String defaultMaleAvatar = 'a2.png';
  static const String defaultFemaleAvatar = 'fa2.png';
  static const String _storageBucket = 'matchvibe-d55f9.firebasestorage.app';
  static const Map<String, String> _defaultPresetDownloadTokens = {
    'male': 'aeb7e524-83f2-492a-a80d-a107374a4fe9',
    'female': '9bbefab7-7734-47f2-bb5a-9d16790436a3',
  };

  /// Compress a PNG image to the given [maxDimension] while keeping the
  /// aspect ratio. Returns the compressed bytes.
  static Future<Uint8List> _compressImage(
    Uint8List pngBytes, {
    int maxDimension = 512,
  }) async {
    // Decode the image
    final codec = await ui.instantiateImageCodec(pngBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final int origWidth = image.width;
    final int origHeight = image.height;

    // Calculate new dimensions maintaining aspect ratio
    int targetWidth;
    int targetHeight;
    if (origWidth > origHeight) {
      targetWidth = maxDimension;
      targetHeight = (origHeight * maxDimension / origWidth).round();
    } else {
      targetHeight = maxDimension;
      targetWidth = (origWidth * maxDimension / origHeight).round();
    }

    // Only downscale — don't upscale small images
    if (origWidth <= maxDimension && origHeight <= maxDimension) {
      targetWidth = origWidth;
      targetHeight = origHeight;
    }

    debugPrint(
        '   🔄 Compressing: ${origWidth}x$origHeight → ${targetWidth}x$targetHeight');

    // Draw to a picture recorder at the target size
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, origWidth.toDouble(), origHeight.toDouble()),
      ui.Rect.fromLTWH(
          0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final resized = await picture.toImage(targetWidth, targetHeight);

    // Encode as PNG (Flutter's dart:ui only supports PNG encoding)
    final byteData =
        await resized.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    resized.dispose();

    if (byteData == null) {
      debugPrint('   ⚠️  Compression failed, using original bytes');
      return pngBytes;
    }

    final compressed = byteData.buffer.asUint8List();
    debugPrint(
        '   📦 Compressed size: ${compressed.length} bytes (was ${pngBytes.length})');
    return compressed;
  }

  // ── Upload a premade avatar asset ─────────────────────────────────

  /// Upload a premade avatar asset to Firebase Storage.
  ///
  /// [firebaseUid] – the authenticated user's Firebase UID.
  /// [avatarName] – filename like `a1.png` or `fa3.png`.
  /// [gender] – `male` or `female`.
  ///
  /// Returns the public download URL.
  static Future<String> uploadAvatar({
    required String firebaseUid,
    required String avatarName,
    required String gender,
  }) async {
    debugPrint('───────────────────────────────────────────────────────');
    debugPrint('🖼️  [AVATAR] Starting preset avatar upload...');
    debugPrint('   👤 Firebase UID: $firebaseUid');
    debugPrint('   🎨 Avatar: $avatarName');
    debugPrint('   ⚧ Gender: $gender');

    final assetPath = gender == 'female'
        ? 'lib/assets/female/$avatarName'
        : 'lib/assets/male/$avatarName';

    debugPrint('   📂 Asset path: $assetPath');

    final ByteData data = await rootBundle.load(assetPath);
    final Uint8List rawBytes = data.buffer.asUint8List();
    debugPrint('   📏 Original asset size: ${rawBytes.length} bytes');

    final Uint8List bytes = await _compressImage(rawBytes);

    final ref =
        _storage.ref().child('avatars/$firebaseUid/$avatarName');
    final metadata = SettableMetadata(
      contentType: 'image/png',
      customMetadata: {'gender': gender, 'originalAsset': avatarName},
    );

    debugPrint('   📤 Uploading to Firebase Storage...');
    final uploadTask = ref.putData(bytes, metadata);

    uploadTask.snapshotEvents.listen((event) {
      final progress = event.bytesTransferred / event.totalBytes;
      debugPrint(
          '   📊 Upload progress: ${(progress * 100).toStringAsFixed(0)}%');
    });

    await uploadTask;
    debugPrint('   ✅ Upload complete');

    final downloadUrl = await ref.getDownloadURL();
    debugPrint('   🔗 Download URL: $downloadUrl');
    debugPrint('───────────────────────────────────────────────────────');

    return downloadUrl;
  }

  /// Resolve a preset avatar's public URL from Firebase Storage.
  ///
  /// Presets are expected under:
  ///   `avatars/presets/{male|female}/{avatarName}`
  static Future<String> getPresetAvatarUrl({
    required String avatarName,
    required String gender,
  }) async {
    final safeGender = gender == 'female' ? 'female' : 'male';
    final cacheKey = '$safeGender/$avatarName';
    final cached = _presetUrlCache[cacheKey];
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final ref =
          _storage.ref().child('avatars/presets/$safeGender/$avatarName');
      final url = await ref.getDownloadURL();
      _presetUrlCache[cacheKey] = url;
      return url;
    } catch (error) {
      debugPrint(
          '⚠️ [AVATAR] Failed to resolve preset URL for $cacheKey via SDK: $error');
    }

    final defaultAvatar = getDefaultAvatarName(safeGender);
    final defaultCacheKey = '$safeGender/$defaultAvatar';
    final cachedDefault = _presetUrlCache[defaultCacheKey];
    if (cachedDefault != null && cachedDefault.isNotEmpty) {
      _presetUrlCache[cacheKey] = cachedDefault;
      return cachedDefault;
    }

    if (avatarName != defaultAvatar) {
      try {
        final defaultRef =
            _storage.ref().child('avatars/presets/$safeGender/$defaultAvatar');
        final defaultUrl = await defaultRef.getDownloadURL();
        _presetUrlCache[defaultCacheKey] = defaultUrl;
        _presetUrlCache[cacheKey] = defaultUrl;
        return defaultUrl;
      } catch (error) {
        debugPrint(
            '⚠️ [AVATAR] Failed default preset SDK URL for $defaultCacheKey: $error');
      }
    }

    // Last-resort fallback using permanent download-token URLs from seeded files.
    final publicDefaultUrl = _buildTokenizedDefaultPresetUrl(safeGender);
    _presetUrlCache[defaultCacheKey] = publicDefaultUrl;
    _presetUrlCache[cacheKey] = publicDefaultUrl;
    return publicDefaultUrl;
  }

  /// Returns the default preset avatar file name for a given gender.
  static String getDefaultAvatarName(String? gender) {
    return gender == 'female' ? defaultFemaleAvatar : defaultMaleAvatar;
  }

  /// Returns the currently available preset avatar names for gender.
  ///
  /// At the moment, we intentionally expose only the seeded defaults.
  static List<String> getAvailablePresetAvatarNames(String? gender) {
    return [getDefaultAvatarName(gender)];
  }

  static String _buildTokenizedDefaultPresetUrl(String safeGender) {
    final avatarName = getDefaultAvatarName(safeGender);
    final token = _defaultPresetDownloadTokens[safeGender];
    final remotePath = Uri.encodeComponent('avatars/presets/$safeGender/$avatarName');
    return 'https://firebasestorage.googleapis.com/v0/b/$_storageBucket/o/$remotePath?alt=media&token=$token';
  }

  /// Returns true when [url] points to a preset avatar in Firebase Storage.
  static bool isPresetAvatarUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final decoded = Uri.decodeFull(url);
    return decoded.contains('avatars/presets/male/') ||
        decoded.contains('avatars/presets/female/');
  }

  /// Extract preset avatar file name (e.g. `a1.png`) from a preset URL.
  static String? extractPresetAvatarName(String? url) {
    if (!isPresetAvatarUrl(url)) return null;
    final decoded = Uri.decodeFull(url!);
    final match = RegExp(r'avatars/presets/(male|female)/([^?&/]+)')
        .firstMatch(decoded);
    return match?.group(2);
  }

  // ── Upload a gallery image ────────────────────────────────────────

  /// Upload raw image bytes (from the gallery) to Firebase Storage.
  ///
  /// [firebaseUid] – the authenticated user's Firebase UID.
  /// [imageBytes] – raw file bytes.
  /// [fileName] – original filename (used for extension detection).
  ///
  /// Returns the public download URL.
  static Future<String> uploadGalleryImage({
    required String firebaseUid,
    required Uint8List imageBytes,
    String fileName = 'gallery.png',
  }) async {
    debugPrint('───────────────────────────────────────────────────────');
    debugPrint('🖼️  [AVATAR] Starting gallery image upload...');
    debugPrint('   👤 Firebase UID: $firebaseUid');
    debugPrint('   📏 Original size: ${imageBytes.length} bytes');

    // Compress to a reasonable size
    final Uint8List compressed = await _compressImage(imageBytes, maxDimension: 512);

    // Determine content type from extension
    final ext = fileName.split('.').last.toLowerCase();
    final contentType = (ext == 'jpg' || ext == 'jpeg')
        ? 'image/jpeg'
        : 'image/png';

    // Always store under a predictable key so re-uploads overwrite
    final storagePath = 'avatars/$firebaseUid/gallery_avatar.png';
    final ref = _storage.ref().child(storagePath);
    final metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: {'source': 'gallery', 'originalFileName': fileName},
    );

    debugPrint('   📤 Uploading gallery image to Firebase Storage...');
    final uploadTask = ref.putData(compressed, metadata);

    uploadTask.snapshotEvents.listen((event) {
      final progress = event.bytesTransferred / event.totalBytes;
      debugPrint(
          '   📊 Upload progress: ${(progress * 100).toStringAsFixed(0)}%');
    });

    await uploadTask;
    debugPrint('   ✅ Gallery image upload complete');

    final downloadUrl = await ref.getDownloadURL();
    debugPrint('   🔗 Download URL: $downloadUrl');
    debugPrint('───────────────────────────────────────────────────────');

    return downloadUrl;
  }
}
