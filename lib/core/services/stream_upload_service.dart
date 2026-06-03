import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';

class StreamUploadResult {
  const StreamUploadResult({
    required this.uploadURL,
    required this.sessionId,
  });

  final String uploadURL;
  final String sessionId;
}

class StreamUploadService {
  final ApiClient _api = ApiClient();

  Future<StreamUploadResult> createDirectUpload({
    required String contentClass,
  }) async {
    final response = await _api.post(
      '/stream/direct-upload',
      data: {'contentClass': contentClass},
    );
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    return StreamUploadResult(
      uploadURL: data['uploadURL'] as String,
      sessionId: data['sessionId'] as String,
    );
  }

  Future<String> pollUntilReady(
    String sessionId, {
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final response = await _api.get('/stream/upload-status/$sessionId');
      final status = response.data['data']?['processingStatus'] as String?;
      if (status == 'ready') return sessionId;
      if (status == 'failed') {
        throw Exception('Video processing failed');
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    throw Exception('Video upload timed out');
  }

  Future<void> uploadFile({
    required String uploadURL,
    required File file,
    void Function(int sent, int total)? onProgress,
  }) async {
    final bytes = await file.readAsBytes();
    final dio = Dio();
    await dio.post<void>(
      uploadURL,
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: 'upload.mp4'),
      }),
      onSendProgress: onProgress,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
        validateStatus: (s) => s != null && s < 500,
      ),
    );
  }
}
