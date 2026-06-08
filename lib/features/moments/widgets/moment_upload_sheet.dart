import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/image_upload_service.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../models/moments_models.dart';
import '../providers/moments_providers.dart';
import '../services/moments_api_service.dart';
import '../services/moments_video_upload_helper.dart';

Future<void> showMomentUploadSheet(
  BuildContext context, {
  MomentsUploadContentType initialType = MomentsUploadContentType.moment,
  MomentsMediaKind initialMediaKind = MomentsMediaKind.photo,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: ColoredBox(
        color: AppBrandGradients.accountMenuPageBackground,
        child: MomentUploadSheet(
          initialType: initialType,
          initialMediaKind: initialMediaKind,
        ),
      ),
    ),
  );
}

class MomentUploadSheet extends ConsumerStatefulWidget {
  const MomentUploadSheet({
    super.key,
    required this.initialType,
    this.initialMediaKind = MomentsMediaKind.photo,
  });

  final MomentsUploadContentType initialType;
  final MomentsMediaKind initialMediaKind;

  @override
  ConsumerState<MomentUploadSheet> createState() => _MomentUploadSheetState();
}

class _MomentUploadSheetState extends ConsumerState<MomentUploadSheet> {
  late MomentsUploadContentType _contentType;
  MomentsMediaKind _mediaKind = MomentsMediaKind.photo;
  bool _paid = false;
  final _captionController = TextEditingController();
  bool _uploading = false;
  double _progress = 0;
  String _status = '';

  final _momentsApi = MomentsApiService();
  final _videoHelper = MomentsVideoUploadHelper();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _contentType = widget.initialType;
    _mediaKind = widget.initialMediaKind;
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload(ImageSource source, {required bool video}) async {
    setState(() {
      _uploading = true;
      _progress = 0;
      _status = video ? 'Preparing video…' : 'Preparing photo…';
    });
    try {
      if (video) {
        final picked = await _picker.pickVideo(source: source);
        if (picked == null) return;
        final file = File(picked.path);
        final contentClass =
            _contentType == MomentsUploadContentType.story ? 'story' : 'moment';
        setState(() => _status = 'Uploading video…');
        final sessionId = await _videoHelper.uploadVideo(
          contentClass: contentClass,
          file: file,
          onProgress: (p) => setState(() => _progress = p),
        );
        ref.read(pendingMediaSessionsProvider.notifier).state = {
          ...ref.read(pendingMediaSessionsProvider),
          sessionId,
        };
        final caption = _captionController.text.trim();
        if (_contentType == MomentsUploadContentType.story) {
          await _momentsApi.createStory(
            type: 'video',
            streamSessionId: sessionId,
            caption: caption.isEmpty ? null : caption,
          );
        } else {
          String? thumbSessionId;
          final thumb = await _picker.pickImage(source: ImageSource.gallery);
          if (thumb != null) {
            setState(() => _status = 'Uploading thumbnail…');
            final bytes = await thumb.readAsBytes();
            final thumbResult = await ImageUploadService.uploadMomentThumbnail(
              bytes: bytes,
              fileName: thumb.name,
            );
            thumbSessionId = thumbResult.sessionId;
          }
          await _momentsApi.createMoment(
            type: 'video',
            accessType: _paid ? 'paid' : 'free',
            streamSessionId: sessionId,
            thumbnailSessionId: thumbSessionId,
            caption: caption.isEmpty ? null : caption,
          );
        }
      } else {
        final picked = await _picker.pickImage(source: source);
        if (picked == null) return;
        setState(() => _status = 'Uploading photo…');
        final bytes = await picked.readAsBytes();
        if (_contentType == MomentsUploadContentType.story) {
          final result = await ImageUploadService.uploadStoryImage(
            bytes: bytes,
            fileName: picked.name,
          );
          await _momentsApi.createStory(
            type: 'image',
            imageSessionId: result.sessionId,
            caption: _captionController.text.trim().isEmpty
                ? null
                : _captionController.text.trim(),
          );
        } else {
          final result = await ImageUploadService.uploadMomentPhoto(
            bytes: bytes,
            fileName: picked.name,
          );
          await _momentsApi.createMoment(
            type: 'photo',
            accessType: _paid ? 'paid' : 'free',
            imageSessionId: result.sessionId,
            caption: _captionController.text.trim().isEmpty
                ? null
                : _captionController.text.trim(),
          );
        }
      }
      ref.invalidate(storiesBarProvider);
      ref.invalidate(popularFeedProvider);
      ref.invalidate(followingFeedProvider);
      ref.invalidate(myStoriesProvider);
      ref.invalidate(myMomentsProvider);
      ref.invalidate(creatorMomentsAnalyticsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _contentType == MomentsUploadContentType.story
                  ? 'Story uploaded'
                  : 'Moment uploaded',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _progress = 0;
          _status = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final title = _contentType == MomentsUploadContentType.story
        ? 'Upload Story'
        : 'Upload Moment';
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BrandSheetHeader(title: title),
          const SizedBox(height: 12),
          SegmentedButton<MomentsUploadContentType>(
            segments: const [
              ButtonSegment(
                value: MomentsUploadContentType.story,
                label: Text('Story'),
              ),
              ButtonSegment(
                value: MomentsUploadContentType.moment,
                label: Text('Moment'),
              ),
            ],
            selected: {_contentType},
            onSelectionChanged: _uploading
                ? null
                : (s) => setState(() => _contentType = s.first),
          ),
          const SizedBox(height: 12),
          SegmentedButton<MomentsMediaKind>(
            segments: const [
              ButtonSegment(value: MomentsMediaKind.photo, label: Text('Photo')),
              ButtonSegment(value: MomentsMediaKind.video, label: Text('Video')),
            ],
            selected: {_mediaKind},
            onSelectionChanged: _uploading
                ? null
                : (s) => setState(() => _mediaKind = s.first),
          ),
          if (_contentType == MomentsUploadContentType.moment) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Paid content'),
              subtitle: Text(
                _mediaKind == MomentsMediaKind.video
                    ? 'Unlock for 30 coins'
                    : 'Unlock for 10 coins',
              ),
              value: _paid,
              onChanged: _uploading ? null : (v) => setState(() => _paid = v),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _captionController,
            enabled: !_uploading,
            decoration: const InputDecoration(
              labelText: 'Caption (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          if (_uploading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_status, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _uploading
                ? null
                : () => _pickAndUpload(
                      ImageSource.gallery,
                      video: _mediaKind == MomentsMediaKind.video,
                    ),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose from gallery'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _uploading
                ? null
                : () => _pickAndUpload(
                      ImageSource.camera,
                      video: _mediaKind == MomentsMediaKind.video,
                    ),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Use camera'),
          ),
        ],
      ),
    );
  }
}
