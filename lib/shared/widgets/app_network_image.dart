/// Single source of truth for ALL remote image rendering.
///
/// Implements the rules from plan §7.4 and §16.4:
///   - finite `width`/`height` (asserted in debug, defensive throw in release)
///   - decoder sized to `(size * devicePixelRatio).round()` so we never decode
///     a 2K image into a 64dp avatar
///   - blurhash placeholder when [blurhash] is provided (instant, no network)
///   - shimmer skeleton fallback when no blurhash
///   - graceful error fallback (custom widget OR icon)
///   - 120ms fade-in when no blurhash present (zero-fade if blurhash matches
///     final shape — visual continuity)
///   - Hero wrapping (optional [heroTag]) so feed→profile transitions reuse the
///     already-decoded texture
///
/// The widget intentionally builds a single [CachedNetworkImageProvider]
/// instance per widget lifetime to keep `imageCache` deduplication efficient
/// across rebuilds. Switch widgets (don't mutate URL in-place) when the source
/// changes.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../core/images/image_cache_managers.dart';
import '../../core/services/image_render_metrics_reporter.dart';

class AppNetworkImage extends StatefulWidget {
  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.blurhash,
    this.placeholder,
    this.errorFallback,
    this.errorIcon,
    this.cacheManager,
    this.fadeIn = const Duration(milliseconds: 120),
    this.timeout = const Duration(seconds: 10),
    this.heroTag,
    this.semanticLabel,
    this.variantTag,
    this.memoryPlaceholder,
    this.onImageDecoded,
  });

  /// Pre-resolved variant URL. May be null/empty → renders the fallback.
  final String? imageUrl;

  /// Logical pixel size — required so we can compute decode sizing.
  final double width;
  final double height;

  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Persisted 4x3-component blurhash. When present, used as the placeholder.
  final String? blurhash;

  /// Optional override for the placeholder widget. Takes priority over
  /// [blurhash] when both are provided.
  final Widget? placeholder;

  /// Optional widget shown when the image fails to load. Takes priority over
  /// [errorIcon].
  final Widget? errorFallback;
  final IconData? errorIcon;

  final BaseCacheManager? cacheManager;
  final Duration fadeIn;
  final Duration timeout;

  /// When set, wraps the image in a [Hero] for shared-element transitions.
  final String? heroTag;
  final String? semanticLabel;

  /// Cloudflare variant tag for render-latency telemetry (e.g. "avatarMd").
  /// When null, render telemetry is skipped for this instance.
  final String? variantTag;

  /// Local bytes shown under the network placeholder until the remote image decodes.
  final Uint8List? memoryPlaceholder;

  /// Called once when the remote image has decoded and is ready to paint.
  final VoidCallback? onImageDecoded;

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  /// Wall-clock stopwatch from first paint of the widget until the
  /// decoded image arrives. We restart it on URL change so URL swaps are
  /// timed independently.
  late final Stopwatch _renderClock;
  String? _trackedUrl;

  /// Duplicate-completion guard — `ImageStreamListener` can fire twice
  /// (placeholder + final) on some platforms, and the Flutter framework
  /// itself may emit redundant completion callbacks via `imageBuilder`.
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _renderClock = Stopwatch()..start();
  }

  @override
  void didUpdateWidget(covariant AppNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _reported = false;
      _trackedUrl = null;
      _renderClock
        ..reset()
        ..start();
    }
  }

  void _onDecoded() {
    if (_reported) return;
    _reported = true;
    _renderClock.stop();
    widget.onImageDecoded?.call();
    final variant = widget.variantTag;
    if (variant == null || variant.isEmpty) return;
    final elapsedMs = _renderClock.elapsedMilliseconds;
    if (elapsedMs < 0) return;
    ImageRenderMetricsReporter.instance.record(
      variant: variant,
      latencyMs: elapsedMs,
      decoded: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.width.isFinite && widget.height.isFinite,
      'AppNetworkImage requires finite width/height for decode sizing',
    );
    if (!widget.width.isFinite || !widget.height.isFinite) {
      throw ArgumentError(
        'AppNetworkImage requires finite size; got ${widget.width}x${widget.height}',
      );
    }

    final clipRadius = widget.borderRadius;

    final url = widget.imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return _wrapHero(_buildError(context, clipRadius));
    }

    if (_trackedUrl != url) {
      _trackedUrl = url;
      _reported = false;
      _renderClock
        ..reset()
        ..start();
    }

    final dpr = MediaQuery.of(context).devicePixelRatio;
    final memW = (widget.width * dpr).round().clamp(1, 4096);
    final memH = (widget.height * dpr).round().clamp(1, 4096);
    final manager = widget.cacheManager ?? avatarCacheManager;
    final hasBlurhash =
        (widget.blurhash != null && widget.blurhash!.trim().isNotEmpty);

    final Widget image = CachedNetworkImage(
      imageUrl: url,
      cacheKey: url,
      cacheManager: manager,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      memCacheWidth: memW,
      memCacheHeight: memH,
      maxWidthDiskCache: memW * 2,
      maxHeightDiskCache: memH * 2,
      fadeInDuration: hasBlurhash ? Duration.zero : widget.fadeIn,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      placeholder: (context, _) => _buildPlaceholder(context),
      errorWidget: (context, _, error) {
        if (kDebugMode) {
          final tag = widget.variantTag;
          final shortUrl = url.length > 96 ? '${url.substring(0, 96)}…' : url;
          debugPrint(
            '[AppNetworkImage] load failed'
            '${tag != null && tag.isNotEmpty ? ' variant=$tag' : ''}'
            ' url=$shortUrl error=$error',
          );
        }
        return _buildError(context, clipRadius);
      },
      imageBuilder: (context, imageProvider) {
        // CachedNetworkImage calls this exactly when the bytes are decoded
        // and ready to paint. We latch on the first hit only.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _onDecoded();
        });
        return Image(
          image: imageProvider,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
        );
      },
    );

    Widget framed = SizedBox(
      width: widget.width,
      height: widget.height,
      child: clipRadius == null
          ? image
          : ClipRRect(borderRadius: clipRadius, child: image),
    );

    if (widget.semanticLabel != null) {
      framed = Semantics(
        label: widget.semanticLabel,
        image: true,
        child: framed,
      );
    }

    return _wrapHero(framed);
  }

  Widget _wrapHero(Widget child) {
    final tag = widget.heroTag;
    if (tag == null || tag.isEmpty) return child;
    return Hero(tag: tag, child: child);
  }

  Widget _buildPlaceholder(BuildContext context) {
    if (widget.placeholder != null) return widget.placeholder!;
    final radius = widget.borderRadius;
    final memory = widget.memoryPlaceholder;
    if (memory != null && memory.isNotEmpty) {
      final memImage = Image.memory(
        memory,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
      );
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: radius == null
            ? memImage
            : ClipRRect(borderRadius: radius, child: memImage),
      );
    }
    if (widget.blurhash != null && widget.blurhash!.trim().isNotEmpty) {
      try {
        final blur = BlurHash(
          hash: widget.blurhash!.trim(),
          decodingWidth: 32,
          decodingHeight: 32,
        );
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: radius == null
              ? blur
              : ClipRRect(borderRadius: radius, child: blur),
        );
      } catch (e) {
        if (kDebugMode) debugPrint('[AppNetworkImage] invalid blurhash: $e');
      }
    }
    return _ShimmerSkeleton(
      width: widget.width,
      height: widget.height,
      borderRadius: radius,
    );
  }

  Widget _buildError(BuildContext context, BorderRadius? clip) {
    if (widget.errorFallback != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: clip == null
            ? widget.errorFallback!
            : ClipRRect(borderRadius: clip, child: widget.errorFallback!),
      );
    }
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    final icon = widget.errorIcon ?? Icons.broken_image_outlined;
    final fallback = Container(
      width: widget.width,
      height: widget.height,
      color: bg,
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: (widget.width < widget.height ? widget.width : widget.height) *
            0.32,
      ),
    );
    return clip == null
        ? fallback
        : ClipRRect(borderRadius: clip, child: fallback);
  }
}

class _ShimmerSkeleton extends StatefulWidget {
  const _ShimmerSkeleton({
    required this.width,
    required this.height,
    this.borderRadius,
  });

  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<_ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<_ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(context).colorScheme.surfaceContainerHigh;
    final radius = widget.borderRadius;
    final box = AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final dx = _ctrl.value * 2 - 1;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + dx, -0.3),
              end: Alignment(1 + dx, 0.3),
              colors: [base, highlight, base],
              stops: const [0.25, 0.5, 0.75],
            ),
          ),
        );
      },
    );
    return radius == null ? box : ClipRRect(borderRadius: radius, child: box);
  }
}
