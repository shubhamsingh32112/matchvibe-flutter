/// Full-screen paged gallery viewer with pinch-zoom per image.
///
/// Swipe left/right between [items] when not zoomed. Page scroll is disabled
/// while any page is zoomed in so horizontal drags pan the image instead.
library;

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../core/images/image_cache_managers.dart';
import '../../core/services/image_precache_service.dart';
import 'app_network_image.dart';

/// One image in [PagedGalleryImageViewer].
class GalleryViewerItem {
  const GalleryViewerItem({
    required this.imageUrl,
    this.blurhash,
    this.heroTag,
  });

  final String imageUrl;
  final String? blurhash;

  /// Applied only on the page matching [PagedGalleryImageViewer.initialIndex].
  final String? heroTag;
}

/// Full-screen gallery: horizontal swipe between images, pinch-zoom per page.
class PagedGalleryImageViewer extends StatefulWidget {
  PagedGalleryImageViewer({
    super.key,
    required this.items,
    required this.initialIndex,
    this.showPageIndicator = true,
    this.variantTag = 'galleryXl',
    BaseCacheManager? cacheManager,
  }) : cacheManager = cacheManager ?? galleryCacheManager;

  final List<GalleryViewerItem> items;
  final int initialIndex;
  final bool showPageIndicator;
  final String variantTag;
  final BaseCacheManager cacheManager;

  @override
  State<PagedGalleryImageViewer> createState() =>
      _PagedGalleryImageViewerState();
}

class _PagedGalleryImageViewerState extends State<PagedGalleryImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _pageScrollLocked = false;
  final Map<int, TransformationController> _transformControllers = {};

  @override
  void initState() {
    super.initState();
    final maxIndex = widget.items.length - 1;
    _currentIndex = widget.initialIndex.clamp(0, maxIndex < 0 ? 0 : maxIndex);
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheNeighbors(_currentIndex);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _transformControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TransformationController _controllerFor(int index) {
    return _transformControllers.putIfAbsent(
      index,
      TransformationController.new,
    );
  }

  void _precacheNeighbors(int centerIndex) {
    final urls = widget.items.map((e) => e.imageUrl).toList();
    ImagePrecacheService.precacheGalleryViewerNeighbors(
      context,
      urls,
      centerIndex: centerIndex,
      cacheManager: widget.cacheManager,
    );
  }

  void _onPageChanged(int index) {
    final previousIndex = _currentIndex;
    setState(() {
      _currentIndex = index;
      _pageScrollLocked = false;
    });
    _controllerFor(previousIndex).value = Matrix4.identity();
    _precacheNeighbors(index);
  }

  void _onZoomedChanged(int index, bool zoomed) {
    if (index != _currentIndex) return;
    final locked = zoomed;
    if (_pageScrollLocked == locked) return;
    setState(() => _pageScrollLocked = locked);
  }

  String? _heroTagFor(int index) {
    if (index != widget.initialIndex) return null;
    return widget.items[index].heroTag;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final showIndicator =
        widget.showPageIndicator && widget.items.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: showIndicator
            ? Text('${_currentIndex + 1} / ${widget.items.length}')
            : null,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        allowImplicitScrolling: true,
        physics: _pageScrollLocked
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return Semantics(
            label: 'Photo ${index + 1} of ${widget.items.length}',
            child: _ZoomableGalleryPage(
              key: ValueKey<int>(index),
              transformationController: _controllerFor(index),
              imageUrl: item.imageUrl,
              blurhash: item.blurhash,
              heroTag: _heroTagFor(index),
              width: size.width,
              height: size.height,
              variantTag: widget.variantTag,
              cacheManager: widget.cacheManager,
              isActive: index == _currentIndex,
              onZoomedChanged: (zoomed) => _onZoomedChanged(index, zoomed),
            ),
          );
        },
      ),
    );
  }
}

class _ZoomableGalleryPage extends StatefulWidget {
  const _ZoomableGalleryPage({
    super.key,
    required this.transformationController,
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.variantTag,
    required this.cacheManager,
    required this.isActive,
    required this.onZoomedChanged,
    this.blurhash,
    this.heroTag,
  });

  final TransformationController transformationController;
  final String imageUrl;
  final double width;
  final double height;
  final String? blurhash;
  final String? heroTag;
  final String variantTag;
  final BaseCacheManager cacheManager;
  final bool isActive;
  final ValueChanged<bool> onZoomedChanged;

  @override
  State<_ZoomableGalleryPage> createState() => _ZoomableGalleryPageState();
}

class _ZoomableGalleryPageState extends State<_ZoomableGalleryPage> {
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    widget.transformationController.addListener(_onTransformChanged);
  }

  @override
  void didUpdateWidget(_ZoomableGalleryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && _isZoomed) {
      _setZoomed(false);
    }
  }

  @override
  void dispose() {
    widget.transformationController.removeListener(_onTransformChanged);
    super.dispose();
  }

  void _onTransformChanged() {
    if (!widget.isActive) return;
    final zoomed =
        widget.transformationController.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _isZoomed) {
      _setZoomed(zoomed);
    }
  }

  void _setZoomed(bool zoomed) {
    _isZoomed = zoomed;
    widget.onZoomedChanged(zoomed);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        transformationController: widget.transformationController,
        minScale: 0.5,
        maxScale: 4,
        child: AppNetworkImage(
          imageUrl: widget.imageUrl,
          width: widget.width,
          height: widget.height,
          fit: BoxFit.contain,
          blurhash: widget.blurhash,
          heroTag: widget.heroTag,
          cacheManager: widget.cacheManager,
          errorIcon: Icons.broken_image_outlined,
          variantTag: widget.variantTag,
        ),
      ),
    );
  }
}
