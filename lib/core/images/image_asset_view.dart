/// Frontend model mirroring the backend `serializeImageAsset` shape.
///
/// Carries everything the UI needs to render a Cloudflare image without
/// constructing URLs itself:
///   - imageId  : opaque
///   - dims     : optional (used for aspect-ratio hints / decode sizing)
///   - blurhash : optional 4x3 component string for instant placeholders
///   - urls     : pre-built variant URLs (xs/sm/md/feedTile/callPhoto/callBg)
///   - gallery  : pre-built gallery variant URLs (thumb/md/xl)
library;

import 'package:flutter/foundation.dart';

@immutable
class AvatarUrls {
  const AvatarUrls({
    required this.xs,
    required this.sm,
    required this.md,
    required this.feedTile,
    required this.callPhoto,
    required this.callBg,
  });

  final String xs;
  final String sm;
  final String md;
  final String feedTile;
  final String callPhoto;
  final String callBg;

  static AvatarUrls? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final xs = json['xs'];
    final sm = json['sm'];
    final md = json['md'];
    final feedTile = json['feedTile'];
    final callPhoto = json['callPhoto'];
    final callBg = json['callBg'];
    if (xs is! String || sm is! String || md is! String) return null;
    return AvatarUrls(
      xs: xs,
      sm: sm,
      md: md,
      feedTile: feedTile is String ? feedTile : md,
      callPhoto: callPhoto is String ? callPhoto : md,
      callBg: callBg is String ? callBg : md,
    );
  }
}

@immutable
class GalleryUrls {
  const GalleryUrls({
    required this.thumb,
    required this.md,
    required this.xl,
  });

  final String thumb;
  final String md;
  final String xl;

  static GalleryUrls? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final thumb = json['thumb'];
    final md = json['md'];
    final xl = json['xl'];
    if (thumb is! String || md is! String) return null;
    return GalleryUrls(
      thumb: thumb,
      md: md,
      xl: xl is String ? xl : md,
    );
  }
}

@immutable
class ImageAssetView {
  const ImageAssetView({
    required this.imageId,
    required this.avatarUrls,
    required this.galleryUrls,
    this.blurhash,
    this.width,
    this.height,
  });

  final String imageId;
  final AvatarUrls avatarUrls;
  final GalleryUrls galleryUrls;
  final String? blurhash;
  final int? width;
  final int? height;

  /// Aspect ratio for layout hints. Falls back to 1:1.
  double get aspectRatio {
    if (width == null || height == null || width! <= 0 || height! <= 0) {
      return 1.0;
    }
    return width! / height!;
  }

  static ImageAssetView? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final imageId = json['imageId'];
    final avatarUrls = AvatarUrls.fromJson(json['avatarUrls'] as Map<String, dynamic>?);
    final galleryUrls = GalleryUrls.fromJson(json['galleryUrls'] as Map<String, dynamic>?);
    if (imageId is! String || avatarUrls == null || galleryUrls == null) {
      return null;
    }
    return ImageAssetView(
      imageId: imageId,
      avatarUrls: avatarUrls,
      galleryUrls: galleryUrls,
      blurhash: json['blurhash'] is String ? json['blurhash'] as String : null,
      width: json['width'] is num ? (json['width'] as num).toInt() : null,
      height: json['height'] is num ? (json['height'] as num).toInt() : null,
    );
  }
}

/// Compact avatar-only serialization (the backend `serializeAvatar` shape).
@immutable
class AvatarAssetView {
  const AvatarAssetView({
    required this.imageId,
    required this.avatarUrls,
    this.blurhash,
    this.width,
    this.height,
  });

  final String imageId;
  final AvatarUrls avatarUrls;
  final String? blurhash;
  final int? width;
  final int? height;

  static AvatarAssetView? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final imageId = json['imageId'];
    final avatarUrls = AvatarUrls.fromJson(json['avatarUrls'] as Map<String, dynamic>?);
    if (imageId is! String || avatarUrls == null) return null;
    return AvatarAssetView(
      imageId: imageId,
      avatarUrls: avatarUrls,
      blurhash: json['blurhash'] is String ? json['blurhash'] as String : null,
      width: json['width'] is num ? (json['width'] as num).toInt() : null,
      height: json['height'] is num ? (json['height'] as num).toInt() : null,
    );
  }
}
