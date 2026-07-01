import 'package:flutter/material.dart';

import '../../../shared/styles/app_brand_styles.dart';

/// Brief centered heart animation when the user double-taps to like a reel.
class MomentLikeBurstOverlay extends StatefulWidget {
  const MomentLikeBurstOverlay({
    super.key,
    required this.child,
    required this.onDoubleTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onDoubleTap;
  final bool enabled;

  @override
  State<MomentLikeBurstOverlay> createState() => _MomentLikeBurstOverlayState();
}

class _MomentLikeBurstOverlayState extends State<MomentLikeBurstOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scale = Tween<double>(begin: 0.6, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _opacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.35, 1)),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _controller.reset();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (!widget.enabled || widget.onDoubleTap == null) return;
    widget.onDoubleTap!();
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                if (_controller.value == 0) return const SizedBox.shrink();
                return Center(
                  child: Opacity(
                    opacity: _opacity.value,
                    child: Transform.scale(
                      scale: _scale.value,
                      child: const Icon(
                        Icons.favorite,
                        color: AppBrandGradients.creatorProfileAccentPink,
                        size: 96,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
