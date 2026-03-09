import 'package:equatable/equatable.dart';

/// Model for displaying user profiles in the home feed
/// Used when creators view users
class UserProfileModel extends Equatable {
  final String id;
  final String? username;
  final String? avatar;
  final String? gender;
  final List<String> categories;
  final String? firebaseUid; // Firebase UID for video calls
  final DateTime? createdAt;
  final String? availability; // 'online' or 'offline' - from Redis

  const UserProfileModel({
    required this.id,
    this.username,
    this.avatar,
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
      avatar: json['avatar'] as String?,
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
      'avatar': avatar,
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
        avatar,
        gender,
        categories,
        firebaseUid,
        createdAt,
        availability,
      ];
}
