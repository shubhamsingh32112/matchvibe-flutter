import 'dart:typed_data';

import '../../../core/api/api_client.dart';
import '../../../core/services/image_upload_service.dart';
import '../../../shared/models/creator_model.dart';

/// Gallery upload pipeline (Cloudflare Images direct-upload).
///
/// Flow per plan §10.1:
///   1. [ImageUploadService.uploadGalleryImage] — compresses to WebP off-isolate,
///      strips EXIF, requests a direct-upload session, posts bytes to
///      Cloudflare with retry.
///   2. `POST /creator/profile/gallery/commit { sessionId }` — backend resolves
///      Cloudflare metadata, persists `IImageAsset`, enqueues async blurhash
///      job, returns the updated `gallery` array.
///
/// The legacy Firebase Storage upload (PUT signed URL + storagePath) is gone.
class CreatorGalleryService {
  final ApiClient _apiClient = ApiClient();

  static const int maxImages = 6;

  Future<List<CreatorGalleryImage>> getMyGalleryImages() async {
    final response = await _apiClient.get('/creator/profile');
    final creatorData = response.data['data']?['creator'] as Map<String, dynamic>?;
    final images = (creatorData?['gallery'] ?? creatorData?['galleryImages']) as List?;
    if (images == null) return const [];
    return images
        .map((item) => CreatorGalleryImage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<CreatorGalleryImage>> uploadGalleryImage({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    final uploaded = await ImageUploadService.uploadGalleryImage(
      bytes: imageBytes,
      fileName: fileName,
      draftSlot: 'creator-gallery:$fileName',
    );

    final commitResponse = await _apiClient.post(
      '/creator/profile/gallery/commit',
      data: {
        'sessionId': uploaded.sessionId,
        'fileName': fileName,
      },
    );

    final body = commitResponse.data;
    final dataMap = body is Map<String, dynamic> ? body['data'] as Map<String, dynamic>? : null;
    final committed = (dataMap?['gallery'] ?? dataMap?['galleryImages']) as List?;
    return committed == null
        ? const []
        : committed
            .map((item) => CreatorGalleryImage.fromJson(item as Map<String, dynamic>))
            .toList();
  }

  Future<List<CreatorGalleryImage>> deleteGalleryImage(String imageId) async {
    final response = await _apiClient.delete('/creator/profile/gallery/$imageId');
    final body = response.data;
    final dataMap = body is Map<String, dynamic> ? body['data'] as Map<String, dynamic>? : null;
    final images = (dataMap?['gallery'] ?? dataMap?['galleryImages']) as List?;
    if (images == null) return const [];
    return images
        .map((item) => CreatorGalleryImage.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
