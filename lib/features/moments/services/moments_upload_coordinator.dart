import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/image_upload_service.dart';
import '../models/moments_models.dart';
import '../providers/moments_providers.dart';
import 'moments_api_service.dart';
import 'moments_video_upload_helper.dart';

typedef UploadProgressCallback = void Function(double progress);
typedef UploadStatusCallback = void Function(String status);

class MomentsPickedMedia {
  const MomentsPickedMedia({
    required this.file,
    required this.kind,
  });

  final XFile file;
  final MomentsMediaKind kind;
}

class MomentsUploadCoordinator {
  MomentsUploadCoordinator({
    ImagePicker? picker,
    MomentsApiService? momentsApi,
    MomentsVideoUploadHelper? videoHelper,
  })  : _picker = picker ?? ImagePicker(),
        _momentsApi = momentsApi ?? MomentsApiService(),
        _videoHelper = videoHelper ?? MomentsVideoUploadHelper();

  final ImagePicker _picker;
  final MomentsApiService _momentsApi;
  final MomentsVideoUploadHelper _videoHelper;

  Future<XFile?> pickGalleryMedia() {
    return _picker.pickMedia();
  }

  MomentsPickedMedia classify(XFile file) => classifyMedia(file);

  static MomentsPickedMedia classifyMedia(XFile file) {
    return MomentsPickedMedia(
      file: file,
      kind: isVideo(file) ? MomentsMediaKind.video : MomentsMediaKind.photo,
    );
  }

  static bool isVideo(XFile file) {
    final mime = file.mimeType?.toLowerCase() ?? '';
    if (mime.startsWith('video/')) return true;
    final ext = _fileExtension(file.path);
    return {'.mp4', '.mov', '.m4v', '.webm', '.mkv', '.avi'}.contains(ext);
  }

  static String _fileExtension(String filePath) {
    final dot = filePath.lastIndexOf('.');
    if (dot < 0) return '';
    return filePath.substring(dot).toLowerCase();
  }

  Future<void> uploadStory({
    required XFile file,
    required MomentsMediaKind kind,
    String? caption,
    void Function(String sessionId)? onStreamSessionCreated,
    UploadProgressCallback? onProgress,
    UploadStatusCallback? onStatus,
  }) async {
    final trimmedCaption = caption?.trim();
    final captionOrNull =
        trimmedCaption != null && trimmedCaption.isNotEmpty ? trimmedCaption : null;

    if (kind == MomentsMediaKind.video) {
      onStatus?.call('Uploading video…');
      final sessionId = await _videoHelper.uploadVideo(
        contentClass: 'story',
        file: File(file.path),
        onProgress: onProgress,
        onStatus: onStatus,
      );
      onStreamSessionCreated?.call(sessionId);
      onStatus?.call('Creating story…');
      await _momentsApi.createStory(
        type: 'video',
        streamSessionId: sessionId,
        caption: captionOrNull,
      );
      return;
    }

    onStatus?.call('Uploading photo…');
    final bytes = await file.readAsBytes();
    final result = await ImageUploadService.uploadStoryImage(
      bytes: bytes,
      fileName: file.name,
    );
    onStatus?.call('Creating story…');
    await _momentsApi.createStory(
      type: 'image',
      imageSessionId: result.sessionId,
      caption: captionOrNull,
    );
  }

  Future<int> uploadMoment({
    required XFile file,
    required MomentsMediaKind kind,
    String? caption,
    void Function(String sessionId)? onStreamSessionCreated,
    UploadProgressCallback? onProgress,
    UploadStatusCallback? onStatus,
  }) async {
    final trimmedCaption = caption?.trim();
    final captionOrNull =
        trimmedCaption != null && trimmedCaption.isNotEmpty ? trimmedCaption : null;

    if (kind == MomentsMediaKind.video) {
      onStatus?.call('Uploading video…');
      final sessionId = await _videoHelper.uploadVideo(
        contentClass: 'moment',
        file: File(file.path),
        onProgress: onProgress,
        onStatus: onStatus,
      );
      onStreamSessionCreated?.call(sessionId);
      String? thumbnailSessionId;
      try {
        onStatus?.call('Creating thumbnail…');
        thumbnailSessionId = await _uploadVideoThumbnail(file.path);
      } catch (_) {
        // Stream signed thumbnail is fallback when custom poster fails.
      }
      onStatus?.call('Creating moment…');
      return _momentsApi.createMoment(
        type: 'video',
        streamSessionId: sessionId,
        thumbnailSessionId: thumbnailSessionId,
        caption: captionOrNull,
      );
    }

    onStatus?.call('Uploading photo…');
    final bytes = await file.readAsBytes();
    final result = await ImageUploadService.uploadMomentPhoto(
      bytes: bytes,
      fileName: file.name,
    );
    onStatus?.call('Creating moment…');
    return _momentsApi.createMoment(
      type: 'photo',
      imageSessionId: result.sessionId,
      caption: captionOrNull,
    );
  }

  Future<String?> _uploadVideoThumbnail(String videoPath) async {
    final bytes = await VideoThumbnail.thumbnailData(
      video: videoPath,
      maxWidth: 720,
      quality: 80,
      timeMs: 1000,
    );
    if (bytes.isEmpty) return null;
    final result = await ImageUploadService.uploadMomentThumbnail(
      bytes: Uint8List.fromList(bytes),
      fileName: 'moment-thumb.jpg',
    );
    return result.sessionId;
  }

  void invalidateFeeds(WidgetRef ref) {
    ref.invalidate(storiesBarProvider);
    ref.invalidate(popularFeedProvider);
    ref.invalidate(followingFeedProvider);
    ref.invalidate(myStoriesProvider);
    ref.invalidate(myMomentsProvider);
    ref.invalidate(creatorMomentsAnalyticsProvider);
  }

  void trackPendingStreamSession(WidgetRef ref, String sessionId) {
    ref.read(pendingMediaSessionsProvider.notifier).state = {
      ...ref.read(pendingMediaSessionsProvider),
      sessionId,
    };
  }
}
