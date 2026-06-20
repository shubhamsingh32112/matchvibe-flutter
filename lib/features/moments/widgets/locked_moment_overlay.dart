import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/moments_models.dart';
import '../utils/moments_purchase_helper.dart';
import 'moment_viewer_chrome.dart';

class LockedMomentOverlay extends ConsumerStatefulWidget {
  const LockedMomentOverlay({
    super.key,
    required this.item,
    required this.onUnlocked,
    this.viewerLayout = false,
    this.bottomOverlayInset = 0,
  });

  final MomentFeedItem item;
  final ValueChanged<MomentFeedItem> onUnlocked;
  final bool viewerLayout;
  final double bottomOverlayInset;

  @override
  ConsumerState<LockedMomentOverlay> createState() =>
      _LockedMomentOverlayState();
}

class _LockedMomentOverlayState extends ConsumerState<LockedMomentOverlay> {
  bool _purchasing = false;

  Future<void> _purchase() async {
    if (_purchasing) return;
    setState(() => _purchasing = true);
    try {
      final unlocked = await purchaseMomentWithFeedback(
        context,
        ref,
        widget.item,
      );
      if (unlocked != null) {
        widget.onUnlocked(unlocked);
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlockLabel = momentUnlockLabel(widget.item);

    if (widget.viewerLayout) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            widget.item.media.thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black26),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: Colors.black.withValues(alpha: 0.35)),
          ),
          Positioned(
            left: 16,
            bottom: widget.bottomOverlayInset > 0
                ? widget.bottomOverlayInset + 12
                : 180,
            child: MomentViewerPremiumBadge(
              unlockLabel: unlockLabel,
              onTap: _purchasing ? null : _purchase,
              isLoading: _purchasing,
            ),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          widget.item.media.thumbnailUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: Colors.black26),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(color: Colors.black.withValues(alpha: 0.35)),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, color: AppPalette.onSurface, size: 40),
              const SizedBox(height: 12),
              Text(
                unlockLabel,
                style: const TextStyle(
                  color: AppPalette.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _purchasing ? null : _purchase,
                child: _purchasing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Unlock'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
