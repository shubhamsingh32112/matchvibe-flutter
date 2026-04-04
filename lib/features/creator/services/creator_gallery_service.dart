import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/creator_model.dart';

class CreatorGalleryService {
  final ApiClient _apiClient = ApiClient();

  static const int maxImages = 6;
  static const List<String> allowedContentTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
  ];

  Future<List<CreatorGalleryImage>> getMyGalleryImages() async {
    final response = await _apiClient.get('/creator/profile');
    final creatorData = response.data['data']?['creator'] as Map<String, dynamic>?;
    final images = creatorData?['galleryImages'] as List?;
    if (images == null) return const [];
    return images
        .map((item) => CreatorGalleryImage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<CreatorGalleryImage>> uploadGalleryImage({
    required Uint8List imageBytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    if (!allowedContentTypes.contains(contentType)) {
      throw Exception('Unsupported image type: $contentType');
    }

    final uploadUrlResponse = await _apiClient.post(
      '/creator/profile/gallery/upload-url',
      data: {'contentType': contentType},
    );
    final uploadData = uploadUrlResponse.data['data'] as Map<String, dynamic>;
    final uploadUrl = uploadData['uploadUrl'] as String;
    final imageId = uploadData['imageId'] as String;
    final storagePath = uploadData['storagePath'] as String;

    final rawDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ),
    );

    await rawDio.put(
      uploadUrl,
      data: imageBytes,
      options: Options(
        headers: {
          'Content-Type': contentType,
          'Content-Length': imageBytes.length.toString(),
        },
      ),
    );

    final commitResponse = await _apiClient.post(
      '/creator/profile/gallery/commit',
      data: {
        'imageId': imageId,
        'storagePath': storagePath,
        'fileName': fileName,
      },
    );

    final committed = commitResponse.data['data']?['galleryImages'] as List?;
    return committed == null
        ? const []
        : committed
            .map((item) => CreatorGalleryImage.fromJson(item as Map<String, dynamic>))
            .toList();
  }

  Future<List<CreatorGalleryImage>> deleteGalleryImage(String imageId) async {
    final response = await _apiClient.delete('/creator/profile/gallery/$imageId');
    final images = response.data['data']?['galleryImages'] as List?;
    if (images == null) return const [];
    return images
        .map((item) => CreatorGalleryImage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

}
