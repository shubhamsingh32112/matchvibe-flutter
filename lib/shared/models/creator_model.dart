import 'package:equatable/equatable.dart';

import '../../core/images/image_asset_view.dart';

class CreatorGalleryImage extends Equatable {
  final String id;
  final int position;
  final DateTime? createdAt;

  /// Cloudflare Images view: imageId + variants (thumb/md/xl) + blurhash.
  /// Always present post Phase E — legacy Firebase fields were removed.
  final ImageAssetView? asset;

  const CreatorGalleryImage({
    required this.id,
    required this.position,
    this.createdAt,
    this.asset,
  });

  factory CreatorGalleryImage.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['createdAt'];
    DateTime? createdAt;
    if (createdRaw is String) {
      createdAt = DateTime.tryParse(createdRaw);
    }

    final ImageAssetView? asset = ImageAssetView.fromJson(
      json['image'] as Map<String, dynamic>?,
    );

    return CreatorGalleryImage(
      id: json['id'] as String,
      position: (json['position'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
      asset: asset,
    );
  }

  /// Preview URL for grids/thumbs. Returns null only on broken/legacy rows.
  String? get previewUrl => asset?.galleryUrls.thumb;

  /// Largest URL safe to expose on mobile.
  String? get viewerUrl => asset?.galleryUrls.xl;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'position': position,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, position, createdAt, asset];
}

class CreatorModel extends Equatable {
  final String id;
  final String userId; // MongoDB User ID (REQUIRED - creator always has a user)
  final String? firebaseUid; // Firebase UID for Stream Video calls (null if not available)
  final String name;
  final String about;

  /// Cloudflare Images creator avatar (variants + blurhash + dims).
  /// Source of truth for all avatar rendering.
  final AvatarAssetView? avatar;

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
    this.avatar,
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

  /// Cloudflare `feedTile` variant URL. Null when creator has no Cloudflare
  /// avatar yet (caller should fall back to a preset placeholder).
  String? get feedTileUrl => avatar?.avatarUrls.feedTile;

  /// Blurhash convenience for callers (feed cards, profile transitions).
  String? get avatarBlurhash => avatar?.blurhash;

  factory CreatorModel.fromJson(Map<String, dynamic> json) {
    final gallerySource = json['gallery'] ?? json['galleryImages'];
    return CreatorModel(
      id: json['id'] as String,
      userId: (json['userId'] as String?) ?? '',
      firebaseUid: json['firebaseUid'] as String?,
      name: json['name'] as String,
      about: (json['about'] as String?) ?? '',
      avatar: AvatarAssetView.fromJson(
        json['avatar'] as Map<String, dynamic>?,
      ),
      galleryImages: _parseGalleryImages(gallerySource),
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
    AvatarAssetView? avatar,
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
      avatar: avatar ?? this.avatar,
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
      if (avatar != null) 'avatar': {'imageId': avatar!.imageId},
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
        avatar,
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
