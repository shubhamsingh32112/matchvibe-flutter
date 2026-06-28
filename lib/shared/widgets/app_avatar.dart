/// Centralized avatar renderer.
///
/// Picks the smallest-acceptable Cloudflare variant based on rendered size,
/// applies the avatar cache manager + blurhash placeholder, and falls back to
/// initials when no asset is available.
library;

import 'package:flutter/material.dart';

import '../../core/images/image_asset_view.dart';
import '../../core/images/image_cache_managers.dart';
import 'app_network_image.dart';
import 'avatar_decoration.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.size,
    this.asset,
    this.avatarAsset,
    this.avatarUrls,
    this.blurhash,
    this.imageUrlOverride,
    this.fallbackText,
    this.backgroundColor,
    this.isCircular = true,
    this.heroTag,
    this.borderRadius,
    this.decoration = AvatarDecoration.none,
  });

  final ImageAssetView? asset;
  final AvatarAssetView? avatarAsset;
  final AvatarUrls? avatarUrls;
  final String? blurhash;
  final String? imageUrlOverride;
  final double size;
  final String? fallbackText;
  final Color? backgroundColor;
  final bool isCircular;
  final String? heroTag;
  final BorderRadius? borderRadius;
  final AvatarDecoration decoration;

  @override
  Widget build(BuildContext context) {
    final avatar = _buildAvatarCore(context);
    if (decoration == AvatarDecoration.none) return avatar;

    final frameSize = size * 1.14;
    final assetPath = kAvatarDecorationAssets[decoration];
    return SizedBox(
      width: frameSize,
      height: frameSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (assetPath != null)
            Image.asset(
              assetPath,
              width: frameSize,
              height: frameSize,
              fit: BoxFit.contain,
            )
          else if (decoration == AvatarDecoration.vip)
            _VipGoldRing(size: frameSize),
          avatar,
        ],
      ),
    );
  }

  Widget _buildAvatarCore(BuildContext context) {
    final radius = isCircular
        ? BorderRadius.circular(size / 2)
        : (borderRadius ?? BorderRadius.circular(size / 6));

    final resolvedUrl = _pickUrl();
    final resolvedBlurhash =
        blurhash ?? avatarAsset?.blurhash ?? asset?.blurhash;

    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      return _wrapHero(_buildInitials(context, radius));
    }

    return AppNetworkImage(
      imageUrl: resolvedUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      borderRadius: radius,
      blurhash: resolvedBlurhash,
      cacheManager: avatarCacheManager,
      heroTag: heroTag,
      errorFallback: _buildInitials(context, radius, embedded: true),
      variantTag: _variantTag(),
    );
  }

  String _variantTag() {
    if (size <= 48) return 'avatarXs';
    if (size <= 96) return 'avatarSm';
    if (size <= 192) return 'avatarMd';
    if (size <= 360) return 'callPhoto';
    return 'callBg';
  }

  Widget _wrapHero(Widget child) {
    final tag = heroTag;
    if (tag == null || tag.isEmpty) return child;
    return Hero(tag: tag, child: child);
  }

  String? _pickUrl() {
    if (imageUrlOverride != null && imageUrlOverride!.trim().isNotEmpty) {
      return imageUrlOverride!.trim();
    }
    final urls = avatarUrls ?? avatarAsset?.avatarUrls ?? asset?.avatarUrls;
    if (urls == null) return null;
    if (size <= 48) return urls.xs;
    if (size <= 96) return urls.sm;
    if (size <= 192) return urls.md;
    if (size <= 360) return urls.callPhoto;
    return urls.callBg;
  }

  Widget _buildInitials(
    BuildContext context,
    BorderRadius radius, {
    bool embedded = false,
  }) {
    final bg = backgroundColor ?? Theme.of(context).colorScheme.primary;
    final fg = Theme.of(context).colorScheme.onPrimary;
    final label = (fallbackText ?? '?').trim();
    final text = label.isEmpty ? '?' : label[0].toUpperCase();
    final box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: embedded ? null : radius,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      ),
    );
    return embedded
        ? box
        : ClipRRect(borderRadius: radius, child: box);
  }
}

class _VipGoldRing extends StatelessWidget {
  const _VipGoldRing({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            width: size * 0.05,
            color: const Color(0xFFD4AF37),
          ),
        ),
      ),
    );
  }
}
