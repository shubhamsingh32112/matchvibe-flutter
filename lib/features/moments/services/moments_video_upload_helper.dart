import 'dart:io';

import '../../../core/services/stream_upload_service.dart';

class MomentsVideoUploadHelper {
  MomentsVideoUploadHelper({StreamUploadService? streamUpload})
      : _streamUpload = streamUpload ?? StreamUploadService();

  final StreamUploadService _streamUpload;

  Future<String> uploadVideo({
    required String contentClass,
    required File file,
    void Function(double progress)? onProgress,
  }) async {
    final session = await _streamUpload.createDirectUpload(
      contentClass: contentClass,
    );
    await _streamUpload.uploadFile(
      uploadURL: session.uploadURL,
      file: file,
      onProgress: (sent, total) {
        if (total > 0) onProgress?.call(sent / total);
      },
    );
    await _streamUpload.pollUntilReady(session.sessionId);
    return session.sessionId;
  }
}
