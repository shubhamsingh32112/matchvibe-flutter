class MediaPresentation {
  const MediaPresentation({
    required this.mediaType,
    required this.thumbnailUrl,
    this.playbackUrl,
    this.expiresAtMs,
    this.blurPlaceholder,
    required this.locked,
    this.unlockPriceCoins,
    this.originalPriceCoins,
    this.vipFreeUnlockAvailable,
    this.discountApplied,
    required this.processingStatus,
  });

  final String mediaType;
  final String thumbnailUrl;
  final String? playbackUrl;
  final int? expiresAtMs;
  final String? blurPlaceholder;
  final bool locked;
  final int? unlockPriceCoins;
  final int? originalPriceCoins;
  final bool? vipFreeUnlockAvailable;
  final bool? discountApplied;
  final String processingStatus;

  factory MediaPresentation.fromJson(Map<String, dynamic> json) {
    return MediaPresentation(
      mediaType: json['mediaType'] as String? ?? 'image',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      playbackUrl: json['playbackUrl'] as String?,
      expiresAtMs: (json['expiresAtMs'] as num?)?.toInt(),
      blurPlaceholder: json['blurPlaceholder'] as String?,
      locked: json['locked'] as bool? ?? false,
      unlockPriceCoins: json['unlockPriceCoins'] as int?,
      originalPriceCoins: json['originalPriceCoins'] as int?,
      vipFreeUnlockAvailable: json['vipFreeUnlockAvailable'] as bool?,
      discountApplied: json['discountApplied'] as bool?,
      processingStatus: json['processingStatus'] as String? ?? 'ready',
    );
  }

  bool get isVideo => mediaType == 'video';
  bool get isReady => processingStatus == 'ready';

  MediaPresentation copyWith({
    bool? locked,
    String? playbackUrl,
    int? expiresAtMs,
  }) {
    return MediaPresentation(
      mediaType: mediaType,
      thumbnailUrl: thumbnailUrl,
      playbackUrl: playbackUrl ?? this.playbackUrl,
      expiresAtMs: expiresAtMs ?? this.expiresAtMs,
      blurPlaceholder: blurPlaceholder,
      locked: locked ?? this.locked,
      unlockPriceCoins: unlockPriceCoins,
      originalPriceCoins: originalPriceCoins,
      vipFreeUnlockAvailable: vipFreeUnlockAvailable,
      discountApplied: discountApplied,
      processingStatus: processingStatus,
    );
  }
}

class MomentFeedItem {
  const MomentFeedItem({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    this.creatorAvatarUrl,
    required this.media,
    this.caption,
    required this.createdAt,
    required this.locked,
    this.unlockPriceCoins,
    this.originalPriceCoins,
    this.vipFreeUnlockAvailable,
    this.discountApplied,
    this.isFollowing = false,
    this.viewsCount,
    this.purchaseCount,
    this.accessType,
    this.moderationStatus,
    this.processingStatus,
  });

  final String id;
  final String creatorId;
  final String creatorName;
  final String? creatorAvatarUrl;
  final MediaPresentation media;
  final String? caption;
  final String createdAt;
  final bool locked;
  final int? unlockPriceCoins;
  final int? originalPriceCoins;
  final bool? vipFreeUnlockAvailable;
  final bool? discountApplied;
  final bool isFollowing;
  final int? viewsCount;
  final int? purchaseCount;
  final String? accessType;
  final String? moderationStatus;
  final String? processingStatus;

  factory MomentFeedItem.fromJson(Map<String, dynamic> json) {
    return MomentFeedItem(
      id: json['id'] as String,
      creatorId: json['creatorId'] as String,
      creatorName: json['creatorName'] as String? ?? 'Creator',
      creatorAvatarUrl: json['creatorAvatarUrl'] as String?,
      media: MediaPresentation.fromJson(
        Map<String, dynamic>.from(json['media'] as Map),
      ),
      caption: json['caption'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      locked: json['locked'] as bool? ?? false,
      unlockPriceCoins: json['unlockPriceCoins'] as int?,
      originalPriceCoins: json['originalPriceCoins'] as int?,
      vipFreeUnlockAvailable: json['vipFreeUnlockAvailable'] as bool?,
      discountApplied: json['discountApplied'] as bool?,
      isFollowing: json['isFollowing'] as bool? ?? false,
      viewsCount: json['viewsCount'] as int?,
      purchaseCount: json['purchaseCount'] as int?,
      accessType: json['accessType'] as String?,
      moderationStatus: json['moderationStatus'] as String?,
      processingStatus: json['processingStatus'] as String?,
    );
  }

  MomentFeedItem copyWith({
    bool? locked,
    MediaPresentation? media,
    bool? isFollowing,
    int? unlockPriceCoins,
  }) {
    return MomentFeedItem(
      id: id,
      creatorId: creatorId,
      creatorName: creatorName,
      creatorAvatarUrl: creatorAvatarUrl,
      media: media ?? this.media,
      caption: caption,
      createdAt: createdAt,
      locked: locked ?? this.locked,
      unlockPriceCoins: unlockPriceCoins ?? this.unlockPriceCoins,
      isFollowing: isFollowing ?? this.isFollowing,
      viewsCount: viewsCount,
      purchaseCount: purchaseCount,
      accessType: accessType,
      moderationStatus: moderationStatus,
    );
  }
}

class StoryPresentation {
  const StoryPresentation({
    required this.id,
    required this.creatorId,
    required this.type,
    required this.media,
    this.caption,
    required this.createdAt,
    required this.expiresAt,
    this.viewsCount,
    this.processingStatus,
    this.moderationStatus,
    this.moderationReason,
  });

  final String id;
  final String creatorId;
  final String type;
  final MediaPresentation media;
  final String? caption;
  final String createdAt;
  final String expiresAt;
  final int? viewsCount;
  final String? processingStatus;
  final String? moderationStatus;
  final String? moderationReason;

  factory StoryPresentation.fromJson(Map<String, dynamic> json) {
    return StoryPresentation(
      id: json['id'] as String,
      creatorId: json['creatorId'] as String,
      type: json['type'] as String? ?? 'image',
      media: MediaPresentation.fromJson(
        Map<String, dynamic>.from(json['media'] as Map),
      ),
      caption: json['caption'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      expiresAt: json['expiresAt'] as String? ?? '',
      viewsCount: json['viewsCount'] as int?,
      processingStatus: json['processingStatus'] as String?,
      moderationStatus: json['moderationStatus'] as String?,
      moderationReason: json['moderationReason'] as String?,
    );
  }
}

class StoryGroup {
  const StoryGroup({
    required this.creatorId,
    required this.unseen,
    required this.stories,
    this.creatorName,
    this.creatorAvatarUrl,
    this.creatorFirebaseUid,
  });

  final String creatorId;
  final bool unseen;
  final List<StoryPresentation> stories;
  final String? creatorName;
  final String? creatorAvatarUrl;
  final String? creatorFirebaseUid;

  factory StoryGroup.fromJson(Map<String, dynamic> json) {
    final raw = json['stories'] as List? ?? const [];
    return StoryGroup(
      creatorId: json['creatorId'] as String,
      unseen: json['unseen'] as bool? ?? false,
      creatorName: json['creatorName'] as String?,
      creatorAvatarUrl: json['creatorAvatarUrl'] as String?,
      creatorFirebaseUid: json['creatorFirebaseUid'] as String?,
      stories: raw
          .map((e) => StoryPresentation.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class CreatorSummary {
  const CreatorSummary({
    required this.creatorId,
    required this.followerCount,
    required this.followingCount,
    required this.postCount,
    required this.isFollowing,
  });

  final String creatorId;
  final int followerCount;
  final int followingCount;
  final int postCount;
  final bool isFollowing;

  factory CreatorSummary.fromJson(Map<String, dynamic> json) {
    return CreatorSummary(
      creatorId: json['creatorId'] as String,
      followerCount: json['followerCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
      postCount: json['postCount'] as int? ?? 0,
      isFollowing: json['isFollowing'] as bool? ?? false,
    );
  }
}

class StoryViewer {
  const StoryViewer({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.viewedAt,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final DateTime viewedAt;

  factory StoryViewer.fromJson(Map<String, dynamic> json) {
    return StoryViewer(
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'User',
      avatarUrl: json['avatarUrl'] as String?,
      viewedAt: DateTime.tryParse(json['viewedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

enum MomentsUploadContentType { story, moment }

enum MomentsMediaKind { photo, video }
