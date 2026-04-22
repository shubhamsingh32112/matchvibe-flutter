import 'package:flutter/material.dart';
import '../../core/services/avatar_upload_service.dart';
import '../models/user_model.dart';
import '../models/creator_model.dart';
import '../models/profile_model.dart';

/// A reusable avatar widget that handles:
/// - Creator photos (network URLs from Firebase)
/// - User avatars (URL or premade assets for non-creator users)
/// - Fallback to initials
class AvatarWidget extends StatelessWidget {
  /// Size of the avatar (diameter)
  final double size;

  /// User model (for user avatars)
  final UserModel? user;

  /// Creator model (for creator photos)
  final CreatorModel? creator;

  /// User profile model (for user avatars in profile context)
  final UserProfileModel? userProfile;

  /// Direct avatar string (for cases where we just have the avatar string)
  /// Can be a URL (http/https/data:) or a premade avatar filename
  final String? avatar;

  /// Username for fallback initials
  final String? username;

  /// Name for fallback initials (used for creators)
  final String? name;

  /// Gender for premade avatar selection
  final String? gender;

  /// Role hint to determine creator/admin context.
  final String? role;

  /// Background color for fallback avatar
  final Color? backgroundColor;

  /// Border radius (use 0 for circular, or a value for rounded corners)
  final double? borderRadius;

  const AvatarWidget({
    super.key,
    this.size = 60,
    this.user,
    this.creator,
    this.userProfile,
    this.avatar,
    this.username,
    this.name,
    this.gender,
    this.role,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final creatorContext = _isCreatorContext();

    // Priority 1: Creator photo from CreatorModel
    if (creator != null && creator!.photo.isNotEmpty) {
      if (_isNetworkLike(creator!.photo)) {
        return _buildNetworkAvatar(
          url: creator!.photo,
          fallbackText: creator!.name.isNotEmpty
              ? creator!.name[0].toUpperCase()
              : 'C',
        );
      }
      // Creators must use Firebase/network images only.
      return _buildFallbackAvatar();
    }

    // Priority 2: User avatar from UserModel
    if (user != null && user!.avatar != null && user!.avatar!.isNotEmpty) {
      final avatarStr = user!.avatar!;
      // Creators/admins should only ever use network images.
      if (_isNetworkLike(avatarStr)) {
        return _buildNetworkAvatar(
          url: avatarStr,
          fallbackText: user!.username?.isNotEmpty == true
              ? user!.username![0].toUpperCase()
              : 'U',
        );
      }
      if (creatorContext) {
        return _buildFallbackAvatar();
      }
      // Otherwise, treat as premade avatar filename (legacy)
      return _buildAssetAvatar(
        avatar: avatarStr,
        gender: user!.gender ?? gender ?? 'male',
      );
    }

    // Priority 3: User avatar from UserProfileModel
    if (userProfile != null &&
        userProfile!.avatar != null &&
        userProfile!.avatar!.isNotEmpty) {
      final avatarStr = userProfile!.avatar!;
      // Check if it's a URL (shouldn't be for UserProfileModel, but handle it)
      if (avatarStr.startsWith('http://') ||
          avatarStr.startsWith('https://') ||
          avatarStr.startsWith('data:')) {
        return _buildNetworkAvatar(
          url: avatarStr,
          fallbackText: userProfile!.username?.isNotEmpty == true
              ? userProfile!.username![0].toUpperCase()
              : 'U',
        );
      }
      // Otherwise, treat as premade avatar
      return _buildAssetAvatar(
        avatar: avatarStr,
        gender: userProfile!.gender ?? gender ?? 'male',
      );
    }

    // Priority 4: Direct avatar string
    if (avatar != null && avatar!.isNotEmpty) {
      final avatarStr = avatar!;
      // Check if it's a URL
      if (_isNetworkLike(avatarStr)) {
        return _buildNetworkAvatar(
          url: avatarStr,
          fallbackText: _getFallbackText(),
        );
      }
      if (creatorContext) {
        return _buildFallbackAvatar();
      }
      // Otherwise, treat as premade avatar
      return _buildAssetAvatar(avatar: avatarStr, gender: gender ?? 'male');
    }

    // Priority 7: Fallback to initials
    return _buildFallbackAvatar();
  }

  Widget _buildNetworkAvatar({
    required String url,
    required String fallbackText,
  }) {
    final bgColor = backgroundColor ?? Colors.purple[400]!;
    final radius = borderRadius ?? size / 2;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: size.round(),
        cacheHeight: size.round(),
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackContainer(fallbackText, bgColor, radius);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildFallbackContainer(fallbackText, bgColor, radius);
        },
      ),
    );
  }

  Widget _buildAssetAvatar({required String avatar, required String gender}) {
    final safeGender = gender == 'female' ? 'female' : 'male';
    final radius = borderRadius ?? size / 2;
    final fallbackText = _getFallbackText();
    final bgColor = backgroundColor ?? Colors.purple[400]!;

    return FutureBuilder<String>(
      future: _resolvePresetAvatarUrl(avatar: avatar, gender: safeGender),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildFallbackContainer(fallbackText, bgColor, radius);
        }
        final resolvedUrl = snapshot.data;
        if (resolvedUrl == null || resolvedUrl.isEmpty) {
          return _buildFallbackContainer(fallbackText, bgColor, radius);
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.network(
            resolvedUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: size.round(),
            cacheHeight: size.round(),
            errorBuilder: (context, error, stackTrace) {
              return _buildFallbackContainer(fallbackText, bgColor, radius);
            },
          ),
        );
      },
    );
  }

  Future<String> _resolvePresetAvatarUrl({
    required String avatar,
    required String gender,
  }) async {
    try {
      return await AvatarUploadService.getPresetAvatarUrl(
        avatarName: avatar,
        gender: gender,
      );
    } catch (_) {
      // If a legacy avatar key is missing, force known seeded default.
      final defaultAvatar = AvatarUploadService.getDefaultAvatarName(gender);
      try {
        return await AvatarUploadService.getPresetAvatarUrl(
          avatarName: defaultAvatar,
          gender: gender,
        );
      } catch (_) {
        // Preserve previous behavior by rendering fallback initials.
        return '';
      }
    }
  }

  Widget _buildFallbackAvatar() {
    final bgColor = backgroundColor ?? Colors.purple[400]!;
    final radius = borderRadius ?? size / 2;
    final fallbackText = _getFallbackText();

    return _buildFallbackContainer(fallbackText, bgColor, radius);
  }

  Widget _buildFallbackContainer(String text, Color bgColor, double radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  String _getFallbackText() {
    // Try to get text from various sources
    if (name != null && name!.isNotEmpty) {
      return name![0].toUpperCase();
    }
    if (username != null && username!.isNotEmpty) {
      return username![0].toUpperCase();
    }
    if (user?.username != null && user!.username!.isNotEmpty) {
      return user!.username![0].toUpperCase();
    }
    if (userProfile?.username != null && userProfile!.username!.isNotEmpty) {
      return userProfile!.username![0].toUpperCase();
    }
    if (creator?.name != null && creator!.name.isNotEmpty) {
      return creator!.name[0].toUpperCase();
    }
    // Default fallback
    return '?';
  }

  bool _isNetworkLike(String value) {
    return value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('data:');
  }

  bool _isCreatorContext() {
    final roleHint = (role ?? user?.role ?? '').toLowerCase();
    return creator != null || roleHint == 'creator' || roleHint == 'admin';
  }
}
