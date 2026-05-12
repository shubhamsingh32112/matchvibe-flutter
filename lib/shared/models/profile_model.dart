import 'package:equatable/equatable.dart';

import '../../core/images/image_asset_view.dart';

/// Model for displaying user profiles in the home feed
/// Used when creators view users
class UserProfileModel extends Equatable {
  final String id;
  final String? username;

  /// Cloudflare avatar payload (variants + blurhash). Source of truth for
  /// avatar rendering — legacy string fields were removed in Phase E.
  final AvatarAssetView? avatarAsset;

  final String? gender;
  final List<String> categories;
  final String? firebaseUid; // Firebase UID for video calls
  final DateTime? createdAt;
  final String? availability; // 'online' or 'offline' - from Redis

  const UserProfileModel({
    required this.id,
    this.username,
    this.avatarAsset,
    this.gender,
    this.categories = const [],
    this.firebaseUid,
    this.createdAt,
    this.availability,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String,
      username: json['username'] as String?,
      avatarAsset: AvatarAssetView.fromJson(
        json['avatarAsset'] as Map<String, dynamic>?,
      ),
      gender: json['gender'] as String?,
      categories: json['categories'] != null
          ? List<String>.from(json['categories'] as List)
          : [],
      firebaseUid: json['firebaseUid'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      availability: json['availability'] as String?, // 'online' or 'offline'
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      if (avatarAsset != null) 'avatarAsset': {'imageId': avatarAsset!.imageId},
      'gender': gender,
      'categories': categories,
      'firebaseUid': firebaseUid,
      'createdAt': createdAt?.toIso8601String(),
      'availability': availability,
    };
  }

  @override
  List<Object?> get props => [
        id,
        username,
        avatarAsset,
        gender,
        categories,
        firebaseUid,
        createdAt,
        availability,
      ];
}
