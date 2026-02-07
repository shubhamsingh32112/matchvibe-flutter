import 'package:equatable/equatable.dart';

class CreatorModel extends Equatable {
  final String id;
  final String userId; // MongoDB User ID (REQUIRED - creator always has a user)
  final String? firebaseUid; // Firebase UID for Stream Video calls (null if not available)
  final String name;
  final String about;
  final String photo;
  final List<String>? categories;
  final double price;
  final bool isOnline;
  final bool isFavorite; // User-only: whether current user favorited this creator
  /// Real-time availability from Redis (authoritative).
  /// 'online' = available for calls, 'busy' = unavailable/offline/on-call.
  /// Defaults to 'busy' if not provided (safe default).
  final String availability;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CreatorModel({
    required this.id,
    required this.userId,
    this.firebaseUid,
    required this.name,
    required this.about,
    required this.photo,
    this.categories,
    required this.price,
    this.isOnline = false,
    this.isFavorite = false,
    this.availability = 'busy',
    this.createdAt,
    this.updatedAt,
  });

  factory CreatorModel.fromJson(Map<String, dynamic> json) {
    return CreatorModel(
      id: json['id'] as String,
      userId: json['userId'] as String, // Required - no fallback
      firebaseUid: json['firebaseUid'] as String?,
      name: json['name'] as String,
      about: json['about'] as String,
      photo: json['photo'] as String,
      categories: json['categories'] != null
          ? List<String>.from(json['categories'] as List)
          : null,
      price: (json['price'] as num).toDouble(),
      isOnline: json['isOnline'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
      availability: json['availability'] as String? ?? 'busy',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'firebaseUid': firebaseUid,
      'name': name,
      'about': about,
      'photo': photo,
      'categories': categories,
      'price': price,
      'isOnline': isOnline,
      'isFavorite': isFavorite,
      'availability': availability,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        firebaseUid,
        name,
        about,
        photo,
        categories,
        price,
        isOnline,
        isFavorite,
        availability,
        createdAt,
        updatedAt,
      ];
}
