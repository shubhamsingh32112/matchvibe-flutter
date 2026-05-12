/// Centralized avatar renderer.
///
/// Picks the smallest-acceptable Cloudflare variant based on rendered size,
/// applies the avatar cache manager + blurhash placeholder, and falls back to
/// initials when no asset is available.
///
/// Variant selection (logical dp):
///   - size <= 48      → xs   (64px)
///   - size <= 96      → sm   (128px)
///   - size <= 192     → md   (256px)
///   - size <= 360     → callPhoto (~512px)
///   - else            → callBg    (≤1400px, scale-down)
///
/// True original is structurally unreachable for avatars on mobile.
library;

import 'package:flutter/material.dart';

import '../../core/images/image_asset_view.dart';
import '../../core/images/image_cache_managers.dart';
import 'app_network_image.dart';

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
  });

  /// Either pass [asset] (full ImageAssetView, when both avatar+gallery URLs
  /// are present) ...
  final ImageAssetView? asset;

  /// ... or [avatarAsset] (the compact serializeAvatar shape, no gallery urls) ...
  final AvatarAssetView? avatarAsset;

  /// ... or [avatarUrls] + optional [blurhash] (lowest-level adapter).
  final AvatarUrls? avatarUrls;
  final String? blurhash;

  /// Last-resort: a plain URL string (e.g. from Stream Chat user.image which
  /// doesn't carry blurhash). Use [imageUrlOverride] only when no [asset]/
  /// [avatarUrls] is available.
  final String? imageUrlOverride;

  /// Logical size in dp.
  final double size;

  final String? fallbackText;
  final Color? backgroundColor;
  final bool isCircular;
  final String? heroTag;

  /// When [isCircular] is false, this is used as the corner radius. Defaults
  /// to `size / 6` if also null.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
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
