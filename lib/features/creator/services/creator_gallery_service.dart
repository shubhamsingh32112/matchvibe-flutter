import 'dart:typed_data';

import '../../../core/api/api_client.dart';
import '../../../core/images/image_asset_view.dart';
import '../../../core/services/image_upload_service.dart';
import '../../../shared/models/creator_model.dart';

/// Avatar + gallery from a single `GET /creator/profile` response.
class CreatorProfileSnapshot {
  const CreatorProfileSnapshot({
    this.avatar,
    this.galleryImages = const [],
  });

  final AvatarAssetView? avatar;
  final List<CreatorGalleryImage> galleryImages;
}

/// Gallery upload pipeline (Cloudflare Images direct-upload).
///
/// Flow per plan §10.1:
///   1. [ImageUploadService.uploadGalleryImage] — compresses to WebP off-isolate,
///      strips EXIF, requests a direct-upload session, posts bytes to
///      Cloudflare with retry.
///   2. `POST /creator/profile/gallery/commit { sessionId, galleryItemId? }` —
///      backend resolves Cloudflare metadata, persists `IImageAsset`, enqueues
///      async blurhash job, returns the updated `gallery` array. Pass
///      [galleryItemId] when replacing an existing slot (skips quota increment).
///
/// The legacy Firebase Storage upload (PUT signed URL + storagePath) is gone.
class CreatorGalleryService {
  final ApiClient _apiClient = ApiClient();

  static const int maxImages = 6;

  Future<CreatorProfileSnapshot> getMyCreatorProfile() async {
    final response = await _apiClient.get('/creator/profile');
    final creatorData =
        response.data['data']?['creator'] as Map<String, dynamic>?;
    if (creatorData == null) {
      return const CreatorProfileSnapshot();
    }

    final avatar = AvatarAssetView.fromJson(
          creatorData['avatar'] as Map<String, dynamic>?,
        ) ??
        AvatarAssetView.fromJson(
          creatorData['avatarAsset'] as Map<String, dynamic>?,
        );

    final rawGallery =
        (creatorData['gallery'] ?? creatorData['galleryImages']) as List?;
    final galleryImages = rawGallery == null
        ? const <CreatorGalleryImage>[]
        : rawGallery
            .map((item) {
              if (item is! Map) return null;
              return CreatorGalleryImage.fromJson(
                Map<String, dynamic>.from(item),
              );
            })
            .whereType<CreatorGalleryImage>()
            .where((image) => image.id.isNotEmpty)
            .toList();

    return CreatorProfileSnapshot(
      avatar: avatar,
      galleryImages: galleryImages,
    );
  }

  Future<List<CreatorGalleryImage>> getMyGalleryImages() async {
    final snapshot = await getMyCreatorProfile();
    return snapshot.galleryImages;
  }

  Future<List<CreatorGalleryImage>> uploadGalleryImage({
    required Uint8List imageBytes,
    required String fileName,
    /// When set, replaces the existing gallery slot instead of adding a new one.
    String? galleryItemId,
  }) async {
    final uploaded = await ImageUploadService.uploadGalleryImage(
      bytes: imageBytes,
      fileName: fileName,
      draftSlot: galleryItemId != null && galleryItemId.isNotEmpty
          ? 'creator-gallery:$galleryItemId'
          : 'creator-gallery:$fileName',
    );

    final commitData = <String, dynamic>{
      'sessionId': uploaded.sessionId,
      'fileName': fileName,
    };
    if (galleryItemId != null && galleryItemId.trim().isNotEmpty) {
      commitData['galleryItemId'] = galleryItemId.trim();
    }

    final commitResponse = await _apiClient.post(
      '/creator/profile/gallery/commit',
      data: commitData,
    );

    final body = commitResponse.data;
    final dataMap =
        body is Map<String, dynamic> ? body['data'] as Map<String, dynamic>? : null;
    final committed = (dataMap?['gallery'] ?? dataMap?['galleryImages']) as List?;
    return committed == null
        ? const []
        : committed
            .map((item) {
              if (item is! Map) return null;
              return CreatorGalleryImage.fromJson(
                Map<String, dynamic>.from(item),
              );
            })
            .whereType<CreatorGalleryImage>()
            .where((image) => image.id.isNotEmpty)
            .toList();
  }

  Future<List<CreatorGalleryImage>> deleteGalleryImage(String imageId) async {
    final response =
        await _apiClient.delete('/creator/profile/gallery/$imageId');
    final body = response.data;
    final dataMap =
        body is Map<String, dynamic> ? body['data'] as Map<String, dynamic>? : null;
    final images = (dataMap?['gallery'] ?? dataMap?['galleryImages']) as List?;
    if (images == null) return const [];
    return images
        .map((item) {
          if (item is! Map) return null;
          return CreatorGalleryImage.fromJson(
            Map<String, dynamic>.from(item),
          );
        })
        .whereType<CreatorGalleryImage>()
        .where((image) => image.id.isNotEmpty)
        .toList();
  }
}
