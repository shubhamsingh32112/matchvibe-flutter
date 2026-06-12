import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../shared/styles/app_brand_styles.dart';
import '../models/moments_models.dart';
import '../services/moments_upload_coordinator.dart';
import '../widgets/add_content_gradient_button.dart';

class MomentsUploadReviewScreen extends ConsumerStatefulWidget {
  const MomentsUploadReviewScreen({
    super.key,
    required this.contentType,
    required this.file,
    required this.mediaKind,
    required this.onUploadComplete,
  });

  final MomentsUploadContentType contentType;
  final XFile file;
  final MomentsMediaKind mediaKind;
  final void Function({required bool isStory, required int rewardCoins})
      onUploadComplete;

  @override
  ConsumerState<MomentsUploadReviewScreen> createState() =>
      _MomentsUploadReviewScreenState();
}

class _MomentsUploadReviewScreenState
    extends ConsumerState<MomentsUploadReviewScreen> {
  final _captionController = TextEditingController();
  final _coordinator = MomentsUploadCoordinator();

  bool _uploading = false;
  double _progress = 0;
  String _status = '';

  VideoPlayerController? _videoController;
  bool _videoInitFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.mediaKind == MomentsMediaKind.video) {
      _initVideoPreview();
    }
  }

  Future<void> _initVideoPreview() async {
    try {
      final controller = VideoPlayerController.file(File(widget.file.path));
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _videoController = controller);
    } catch (_) {
      if (mounted) setState(() => _videoInitFailed = true);
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  String get _ctaLabel => widget.contentType == MomentsUploadContentType.story
      ? 'Add Story'
      : 'Add Moment';

  Future<void> _submit() async {
    if (_uploading) return;
    setState(() {
      _uploading = true;
      _progress = 0;
      _status = widget.mediaKind == MomentsMediaKind.video
          ? 'Preparing video…'
          : 'Preparing photo…';
    });

    try {
      final caption = _captionController.text;
      final isStory =
          widget.contentType == MomentsUploadContentType.story;

      if (isStory) {
        await _coordinator.uploadStory(
          file: widget.file,
          kind: widget.mediaKind,
          caption: caption,
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onStatus: (s) {
            if (mounted) setState(() => _status = s);
          },
          onStreamSessionCreated: (sessionId) {
            _coordinator.trackPendingStreamSession(ref, sessionId);
          },
        );
        _coordinator.invalidateFeeds(ref);
        if (!mounted) return;
        widget.onUploadComplete(isStory: true, rewardCoins: 0);
        Navigator.of(context).pop();
        return;
      }

      final rewardCoins = await _coordinator.uploadMoment(
        file: widget.file,
        kind: widget.mediaKind,
        caption: caption,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onStatus: (s) {
          if (mounted) setState(() => _status = s);
        },
        onStreamSessionCreated: (sessionId) {
          _coordinator.trackPendingStreamSession(ref, sessionId);
        },
      );
      _coordinator.invalidateFeeds(ref);
      if (!mounted) return;
      widget.onUploadComplete(isStory: false, rewardCoins: rewardCoins);
      Navigator.of(context).pop();
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppBrandGradients.accountMenuPageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _uploading ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildPreview()),
            const SizedBox(height: 16),
            TextField(
              controller: _captionController,
              enabled: !_uploading,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Caption (optional)',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white54),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
            ),
            if (_uploading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _status,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
            const SizedBox(height: 16),
            AddContentGradientButton(
              label: _ctaLabel,
              enabled: !_uploading,
              onPressed: _uploading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (widget.mediaKind == MomentsMediaKind.photo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          File(widget.file.path),
          fit: BoxFit.contain,
          width: double.infinity,
        ),
      );
    }

    final controller = _videoController;
    if (controller != null && controller.value.isInitialized) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
      );
    }

    if (_videoInitFailed) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam, size: 64, color: Colors.white.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            Text(
              'Video selected',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    return const Center(child: CircularProgressIndicator());
  }
}
