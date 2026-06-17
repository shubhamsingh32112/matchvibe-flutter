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

  bool get _isStory =>
      widget.contentType == MomentsUploadContentType.story;

  String get _ctaLabel => _isStory ? 'Add Story' : 'Post Moment';

  String get _contextLine => _isStory
      ? 'Expires in 24 hours'
      : 'Visible in Moments feed';

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

      if (_isStory) {
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
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppBrandGradients.momentsPageBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _buildPreview()),
          Positioned(
            top: topPadding + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _uploading ? null : () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + bottomInset),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppBrandGradients.momentsPageBackground.withValues(alpha: 0),
                    AppBrandGradients.momentsPageBackground.withValues(alpha: 0.92),
                    AppBrandGradients.momentsPageBackground,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _contextLine,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppBrandGradients.momentsSubtitleColor,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _captionController,
                    enabled: !_uploading,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Caption (optional)',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                      filled: true,
                      fillColor: AppBrandGradients.momentsTrophyBackground,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppBrandGradients.momentsTabActiveColor,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    maxLines: 2,
                  ),
                  if (_uploading) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        minHeight: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        color: AppBrandGradients.momentsTabActiveColor,
                      ),
                    ),
                    if (_status.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _status,
                        style: TextStyle(
                          color: AppBrandGradients.momentsSubtitleColor,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                  const SizedBox(height: 14),
                  AddContentGradientButton(
                    label: _ctaLabel,
                    enabled: !_uploading,
                    onPressed: _uploading ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (widget.mediaKind == MomentsMediaKind.photo) {
      return Image.file(
        File(widget.file.path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    final controller = _videoController;
    if (controller != null && controller.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 160,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppBrandGradients.momentsPageBackground.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_videoInitFailed) {
      return ColoredBox(
        color: AppBrandGradients.momentsTrophyBackground,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam,
                size: 64,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'Video selected',
                style: TextStyle(
                  color: AppBrandGradients.momentsSubtitleColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const Center(
      child: CircularProgressIndicator(
        color: AppBrandGradients.momentsTabActiveColor,
      ),
    );
  }
}
