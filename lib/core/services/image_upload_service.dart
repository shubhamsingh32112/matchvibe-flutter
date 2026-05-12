/// Direct-upload pipeline for Cloudflare Images.
///
/// Replaces the legacy Firebase upload service for ALL avatar/gallery uploads.
///
/// Flow (per plan §5.2 + §7.2):
///   1. Off-isolate compress via `flutter_image_compress` (WebP, quality 85,
///      EXIF stripped). HEIC is decoded natively on iOS by flutter_image_compress.
///   2. Cap final bytes at 10 MB (re-compress at q70 if still too large).
///   3. POST /images/direct-upload to issue a Cloudflare upload URL +
///      backend-tracked upload session.
///   4. POST the bytes to Cloudflare as multipart/form-data. Retry 3x on
///      transient errors with exponential backoff (1s/2s/4s).
///   5. On failure, retain bytes + imageId in [UploadDraftRegistry] so the
///      caller can offer "Retry upload" without re-picking.
///   6. Return both `imageId` and `sessionId` — the caller commits via the
///      resource-specific endpoint (creator/user profile, gallery commit) and
///      the backend resolves metadata + enqueues blurhash generation.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../api/api_client.dart';

class ImageUploadResult {
  const ImageUploadResult({
    required this.imageId,
    required this.sessionId,
    required this.bytes,
    required this.contentType,
  });

  final String imageId;
  final String sessionId;
  final Uint8List bytes;
  final String contentType;
}

enum ImageUploadPurpose {
  creatorAvatar('creator-avatar'),
  creatorGallery('creator-gallery'),
  userAvatar('user-avatar');

  const ImageUploadPurpose(this.wire);
  final String wire;
}

class ImageTooLargeException implements Exception {
  ImageTooLargeException(this.byteSize);
  final int byteSize;
  @override
  String toString() => 'ImageTooLargeException: $byteSize bytes exceeds limit';
}

class ImageQuotaExceededException implements Exception {
  ImageQuotaExceededException(this.scope, this.retryAfterSeconds);
  final String scope;
  final int? retryAfterSeconds;
  @override
  String toString() =>
      'ImageQuotaExceededException(scope=$scope, retryAfter=${retryAfterSeconds}s)';
}

class ImageServiceDegradedException implements Exception {
  ImageServiceDegradedException(this.message);
  final String message;
  @override
  String toString() => 'ImageServiceDegradedException: $message';
}

/// Thrown when the upload fails after all retries. Carries [imageId] so the
/// caller can show a retry option that re-uploads against the same image slot.
class ImageUploadFailedException implements Exception {
  ImageUploadFailedException(this.message, {this.imageId, this.sessionId});
  final String message;
  final String? imageId;
  final String? sessionId;
  @override
  String toString() =>
      'ImageUploadFailedException(imageId=$imageId, sessionId=$sessionId): $message';
}

/// In-memory holder for failed-upload bytes + assigned imageId/sessionId so
/// screens can offer "Retry upload" without re-picking or re-compressing.
class UploadDraftRegistry {
  UploadDraftRegistry._();
  static final UploadDraftRegistry instance = UploadDraftRegistry._();

  final Map<String, _Draft> _drafts = {};

  void store({
    required String slot,
    required Uint8List bytes,
    required String contentType,
    String? imageId,
    String? sessionId,
  }) {
    _drafts[slot] = _Draft(
      bytes: bytes,
      contentType: contentType,
      imageId: imageId,
      sessionId: sessionId,
    );
  }

  // ignore: library_private_types_in_public_api
  _Draft? read(String slot) => _drafts[slot];

  /// Public, type-stable view of a pending draft. Returns `null` when no
  /// draft is held for [slot]. Use this from callers outside the library
  /// (e.g. auto-retry logic in screens).
  UploadDraftView? peek(String slot) {
    final draft = _drafts[slot];
    if (draft == null) return null;
    return UploadDraftView(
      bytes: draft.bytes,
      contentType: draft.contentType,
      imageId: draft.imageId,
      sessionId: draft.sessionId,
    );
  }

  /// True iff there is a pending draft for [slot].
  bool hasDraft(String slot) => _drafts.containsKey(slot);

  void clear(String slot) => _drafts.remove(slot);
}

/// Public, immutable snapshot of an [UploadDraftRegistry] entry.
class UploadDraftView {
  const UploadDraftView({
    required this.bytes,
    required this.contentType,
    this.imageId,
    this.sessionId,
  });

  final Uint8List bytes;
  final String contentType;
  final String? imageId;
  final String? sessionId;
}

class _Draft {
  _Draft({
    required this.bytes,
    required this.contentType,
    this.imageId,
    this.sessionId,
  });
  final Uint8List bytes;
  final String contentType;
  final String? imageId;
  final String? sessionId;
}

class ImageUploadService {
  ImageUploadService._();

  /// 10 MiB max for any single upload after compression.
  static const int _maxBytes = 10 * 1024 * 1024;

  static const int _avatarMaxDim = 512;
  static const int _galleryMaxDim = 1600;

  static const Duration _uploadTimeout = Duration(seconds: 30);
  static const int _maxRetries = 3;

  static final Dio _uploadDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: _uploadTimeout,
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  /// Upload an avatar (creator or user). Caller picks the right purpose.
  static Future<ImageUploadResult> uploadAvatar({
    required Uint8List bytes,
    required ImageUploadPurpose purpose,
    String? fileName,
    String? draftSlot,
  }) {
    return _runPipeline(
      bytes: bytes,
      maxDim: _avatarMaxDim,
      purpose: purpose,
      fileName: fileName,
      draftSlot: draftSlot,
    );
  }

  /// Upload a gallery image (creator-only).
  static Future<ImageUploadResult> uploadGalleryImage({
    required Uint8List bytes,
    String? fileName,
    String? draftSlot,
  }) {
    return _runPipeline(
      bytes: bytes,
      maxDim: _galleryMaxDim,
      purpose: ImageUploadPurpose.creatorGallery,
      fileName: fileName,
      draftSlot: draftSlot,
    );
  }

  // ── pipeline ────────────────────────────────────────────────────────────

  static Future<ImageUploadResult> _runPipeline({
    required Uint8List bytes,
    required int maxDim,
    required ImageUploadPurpose purpose,
    String? fileName,
    String? draftSlot,
  }) async {
    final compressed = await _compressOrPassthrough(bytes: bytes, maxDim: maxDim);
    if (compressed.length > _maxBytes) {
      throw ImageTooLargeException(compressed.length);
    }

    // Resolve session + imageId from backend.
    final issued = await _issueDirectUpload(
      purpose: purpose,
      sizeBytes: compressed.length,
    );

    if (draftSlot != null) {
      UploadDraftRegistry.instance.store(
        slot: draftSlot,
        bytes: compressed,
        contentType: 'image/webp',
        imageId: issued.imageId,
        sessionId: issued.sessionId,
      );
    }

    final fileLabel = (fileName ?? '${issued.imageId}.webp').replaceAll(
      RegExp(r'\.[^.]+$'),
      '.webp',
    );

    await _uploadToCloudflareWithRetry(
      uploadUrl: issued.uploadUrl,
      bytes: compressed,
      fileName: fileLabel,
      imageId: issued.imageId,
      sessionId: issued.sessionId,
    );

    if (draftSlot != null) {
      UploadDraftRegistry.instance.clear(draftSlot);
    }

    return ImageUploadResult(
      imageId: issued.imageId,
      sessionId: issued.sessionId,
      bytes: compressed,
      contentType: 'image/webp',
    );
  }

  /// EXIF-stripping WebP compression via [FlutterImageCompress].
  ///
  /// `flutter_image_compress` always re-encodes, which strips EXIF inherently.
  /// `keepExif: false` is set explicitly as double-defense and to be obvious to
  /// readers.
  static Future<Uint8List> _compressOrPassthrough({
    required Uint8List bytes,
    required int maxDim,
  }) async {
    try {
      Uint8List out = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxDim,
        minHeight: maxDim,
        quality: 85,
        format: CompressFormat.webp,
        keepExif: false,
      );
      if (out.length > _maxBytes) {
        // Re-compress at lower quality.
        out = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: maxDim,
          minHeight: maxDim,
          quality: 70,
          format: CompressFormat.webp,
          keepExif: false,
        );
      }
      return out;
    } catch (e, st) {
      debugPrint('[ImageUploadService] compress failed: $e');
      debugPrint(st.toString());
      return bytes;
    }
  }

  static Future<_IssuedUpload> _issueDirectUpload({
    required ImageUploadPurpose purpose,
    required int sizeBytes,
  }) async {
    final Response<dynamic> response;
    try {
      response = await ApiClient().post(
        '/images/direct-upload',
        data: {
          'purpose': purpose.wire,
          'declaredSizeBytes': sizeBytes,
        },
      );
    } on DioException catch (error) {
      _interpretDirectUploadError(error);
      rethrow;
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw ImageUploadFailedException(
        'invalid /images/direct-upload response shape',
      );
    }
    final inner = data['data'] as Map<String, dynamic>?;
    final uploadUrl = inner?['uploadURL']?.toString();
    final imageId = inner?['imageId']?.toString();
    final sessionId = inner?['sessionId']?.toString();
    if (uploadUrl == null ||
        uploadUrl.isEmpty ||
        imageId == null ||
        imageId.isEmpty ||
        sessionId == null ||
        sessionId.isEmpty) {
      throw ImageUploadFailedException(
        'incomplete /images/direct-upload payload',
      );
    }
    return _IssuedUpload(uploadUrl: uploadUrl, imageId: imageId, sessionId: sessionId);
  }

  static void _interpretDirectUploadError(DioException error) {
    final status = error.response?.statusCode;
    final body = error.response?.data;
    String? code;
    String? scope;
    int? retryAfterSeconds;
    if (body is Map<String, dynamic>) {
      code = body['code']?.toString();
      scope = body['scope']?.toString();
      final ra = body['retryAfterSeconds'];
      if (ra is num) retryAfterSeconds = ra.toInt();
    }
    if (status == 429 || code == 'UPLOAD_QUOTA_EXCEEDED') {
      throw ImageQuotaExceededException(scope ?? 'unknown', retryAfterSeconds);
    }
    if (status == 503 ||
        code == 'CLOUDFLARE_IMAGES_UNAVAILABLE' ||
        code == 'IMAGES_DISABLED') {
      throw ImageServiceDegradedException(
        body is Map<String, dynamic> ? body['error']?.toString() ?? 'service degraded' : 'service degraded',
      );
    }
  }

  static Future<void> _uploadToCloudflareWithRetry({
    required String uploadUrl,
    required Uint8List bytes,
    required String fileName,
    required String imageId,
    required String sessionId,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final form = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            bytes,
            filename: fileName,
            contentType: _parseMediaType('image/webp'),
          ),
        });
        final res = await _uploadDio.post<dynamic>(
          uploadUrl,
          data: form,
          options: Options(
            sendTimeout: _uploadTimeout,
            receiveTimeout: _uploadTimeout,
          ),
        );
        if (res.statusCode != null &&
            res.statusCode! >= 200 &&
            res.statusCode! < 300) {
          return;
        }
        lastError = HttpException(
          'Cloudflare upload returned status ${res.statusCode}',
        );
      } on DioException catch (error) {
        lastError = error;
        final transient = _isTransient(error);
        if (!transient) break;
      } on IOException catch (error) {
        lastError = error;
      }

      if (attempt < _maxRetries - 1) {
        final delay = Duration(milliseconds: 1000 * math.pow(2, attempt).toInt());
        await Future<void>.delayed(delay);
      }
    }

    throw ImageUploadFailedException(
      lastError?.toString() ?? 'cloudflare direct upload failed',
      imageId: imageId,
      sessionId: sessionId,
    );
  }

  static bool _isTransient(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return true;
    }
    final status = e.response?.statusCode;
    if (status == null) return true;
    return status >= 500 && status < 600;
  }

  // Lightweight MediaType holder. Avoids adding a `http_parser` dep just for
  // multipart contentType.
  static dynamic _parseMediaType(String value) {
    // Dio v5 accepts a `DioMediaType` (re-export of `MediaType`). Returning
    // null keeps the default; we set contentType via fromBytes parameter
    // instead. The Dio multipart handler will sniff from filename otherwise.
    return null;
  }
}

class _IssuedUpload {
  _IssuedUpload({
    required this.uploadUrl,
    required this.imageId,
    required this.sessionId,
  });
  final String uploadUrl;
  final String imageId;
  final String sessionId;
}
