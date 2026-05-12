/// Targeted precache helpers for the Cloudflare-images pipeline.
///
/// Per plan §11.1, each helper takes a fixed `count` upper bound so we never
/// drown the `imageCache` with low-priority requests on first scroll.
///
/// All helpers are intentionally fire-and-forget (return `void`); they
/// schedule precache after the current frame via `WidgetsBinding.addPostFrameCallback`
/// so they don't block the build.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../features/recent/models/call_history_model.dart';
import '../../shared/models/creator_model.dart';
import '../../shared/models/profile_model.dart';
import '../images/image_cache_managers.dart';

class ImagePrecacheService {
  ImagePrecacheService._();

  /// First-viewport feed tiles. Default 12 (plan §11.1 — reduced from 20).
  static void precacheFeedTiles(
    BuildContext context,
    List<CreatorModel> creators, {
    int count = 12,
  }) {
    _afterFrame(() {
      for (final c in creators.take(count)) {
        final url = c.feedTileUrl;
        if (url == null || url.isEmpty) continue;
        _precache(context, url, feedCacheManager);
      }
    });
  }

  /// Chat-list avatars (xs variant). Accepts the profile shape used by the
  /// online-users + chat-list providers.
  static void precacheChatAvatars(
    BuildContext context,
    List<UserProfileModel> users, {
    int count = 20,
  }) {
    _afterFrame(() {
      for (final u in users.take(count)) {
        final url = u.avatarAsset?.avatarUrls.xs;
        if (url == null || url.isEmpty) continue;
        _precache(context, url, avatarCacheManager);
      }
    });
  }

  /// Recent-calls avatars (xs variant).
  static void precacheRecentCalls(
    BuildContext context,
    List<CallHistoryModel> calls, {
    int count = 15,
  }) {
    _afterFrame(() {
      for (final c in calls.take(count)) {
        final url = c.otherAvatarAsset?.avatarUrls.xs;
        if (url == null || url.isEmpty) continue;
        _precache(context, url, avatarCacheManager);
      }
    });
  }

  /// Gallery thumbs for a creator (max 6).
  static void precacheCreatorGallery(BuildContext context, CreatorModel c) {
    _afterFrame(() {
      for (final g in c.galleryImages) {
        final url = g.asset?.galleryUrls.thumb;
        if (url == null || url.isEmpty) continue;
        _precache(context, url, galleryCacheManager);
      }
    });
  }

  /// Full-size gallery (xl) — lower priority, post-frame only.
  static void precacheCreatorFullGallery(
    BuildContext context,
    CreatorModel c,
  ) {
    _afterFrame(() {
      for (final g in c.galleryImages) {
        final url = g.asset?.galleryUrls.xl;
        if (url == null || url.isEmpty) continue;
        _precache(context, url, galleryCacheManager);
      }
    });
  }

  static void _afterFrame(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        fn();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ImagePrecacheService] precache batch failed: $e');
        }
      }
    });
  }

  static void _precache(
    BuildContext context,
    String url,
    BaseCacheManager manager,
  ) {
    final provider = CachedNetworkImageProvider(
      url,
      cacheManager: manager,
      cacheKey: url,
    );
    precacheImage(provider, context).catchError((e) {
      if (kDebugMode) {
        debugPrint('[ImagePrecacheService] $url precache failed: $e');
      }
    });
  }
}
