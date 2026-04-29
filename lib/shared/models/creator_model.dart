import 'package:equatable/equatable.dart';

class CreatorGalleryImage extends Equatable {
  final String id;
  final String url;
  final String? thumbnailUrl;
  final String storagePath;
  final int position;
  final DateTime? createdAt;

  const CreatorGalleryImage({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    required this.storagePath,
    required this.position,
    this.createdAt,
  });

  factory CreatorGalleryImage.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['createdAt'];
    DateTime? createdAt;
    if (createdRaw is String) {
      createdAt = DateTime.tryParse(createdRaw);
    }

    return CreatorGalleryImage(
      id: json['id'] as String,
      url: json['url'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      storagePath: json['storagePath'] as String? ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'storagePath': storagePath,
      'position': position,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props =>
      [id, url, thumbnailUrl, storagePath, position, createdAt];
}

class CreatorModel extends Equatable {
  final String id;
  final String userId; // MongoDB User ID (REQUIRED - creator always has a user)
  final String? firebaseUid; // Firebase UID for Stream Video calls (null if not available)
  final String name;
  final String about;
  final String photo;
  /// Resized avatar URL when backend / extension provides it.
  final String? thumbnailPhoto;
  final List<CreatorGalleryImage> galleryImages;
  final List<String>? categories;
  final double price;
  final int? age;
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
    this.thumbnailPhoto,
    this.galleryImages = const [],
    this.categories,
    required this.price,
    this.age,
    this.isOnline = false,
    this.isFavorite = false,
    this.availability = 'busy',
    this.createdAt,
    this.updatedAt,
  });

  /// Prefer small thumbnail for grid when available.
  String get displayPhoto {
    final t = thumbnailPhoto?.trim();
    if (t != null && t.isNotEmpty) return t;
    return photo;
  }

  factory CreatorModel.fromJson(Map<String, dynamic> json) {
    return CreatorModel(
      id: json['id'] as String,
      userId: (json['userId'] as String?) ?? '',
      firebaseUid: json['firebaseUid'] as String?,
      name: json['name'] as String,
      about: (json['about'] as String?) ?? '',
      photo: json['photo'] as String,
      thumbnailPhoto: json['thumbnailPhoto'] as String?,
      galleryImages: _parseGalleryImages(json['galleryImages']),
      categories: json['categories'] != null
          ? List<String>.from(json['categories'] as List)
          : null,
      price: (json['price'] as num).toDouble(),
      age: json['age'] != null ? json['age'] as int? : null,
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

  static List<CreatorGalleryImage> _parseGalleryImages(dynamic raw) {
    if (raw is! List) return const [];
    final out = <CreatorGalleryImage>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        out.add(
          CreatorGalleryImage.fromJson(Map<String, dynamic>.from(item)),
        );
      } catch (_) {
        continue;
      }
    }
    out.sort((a, b) => a.position.compareTo(b.position));
    return out;
  }

  CreatorModel copyWith({
    String? id,
    String? userId,
    String? firebaseUid,
    String? name,
    String? about,
    String? photo,
    String? thumbnailPhoto,
    List<CreatorGalleryImage>? galleryImages,
    List<String>? categories,
    double? price,
    int? age,
    bool? isOnline,
    bool? isFavorite,
    String? availability,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CreatorModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      name: name ?? this.name,
      about: about ?? this.about,
      photo: photo ?? this.photo,
      thumbnailPhoto: thumbnailPhoto ?? this.thumbnailPhoto,
      galleryImages: galleryImages ?? this.galleryImages,
      categories: categories ?? this.categories,
      price: price ?? this.price,
      age: age ?? this.age,
      isOnline: isOnline ?? this.isOnline,
      isFavorite: isFavorite ?? this.isFavorite,
      availability: availability ?? this.availability,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
      'thumbnailPhoto': thumbnailPhoto,
      'galleryImages': galleryImages.map((e) => e.toJson()).toList(),
      'categories': categories,
      'price': price,
      'age': age,
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
        thumbnailPhoto,
        galleryImages,
        categories,
        price,
        age,
        isOnline,
        isFavorite,
        availability,
        createdAt,
        updatedAt,
      ];
}
