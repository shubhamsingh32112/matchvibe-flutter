class MomentsFeedSections {
  const MomentsFeedSections({this.previewEndIndex = 0});

  final int previewEndIndex;

  factory MomentsFeedSections.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MomentsFeedSections();
    return MomentsFeedSections(
      previewEndIndex: (json['previewEndIndex'] as num?)?.toInt() ?? 0,
    );
  }
}

class MomentsFeedPage {
  const MomentsFeedPage({
    required this.items,
    this.sections = const MomentsFeedSections(),
    this.nextCursor,
    this.hasMore = false,
    this.nextOffset = 0,
  });

  final List<MomentFeedItem> items;
  final MomentsFeedSections sections;
  final String? nextCursor;
  final bool hasMore;
  final int nextOffset;
}

class MediaPresentation {
  const MediaPresentation({
    required this.mediaType,
    required this.thumbnailUrl,
    this.playbackUrl,
    this.expiresAtMs,
    this.blurPlaceholder,
    required this.locked,
    required this.processingStatus,
  });

  final String mediaType;
  final String thumbnailUrl;
  final String? playbackUrl;
  final int? expiresAtMs;
  final String? blurPlaceholder;
  final bool locked;
  final String processingStatus;

  factory MediaPresentation.fromJson(Map<String, dynamic> json) {
    return MediaPresentation(
      mediaType: json['mediaType'] as String? ?? 'image',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      playbackUrl: json['playbackUrl'] as String?,
      expiresAtMs: (json['expiresAtMs'] as num?)?.toInt(),
      blurPlaceholder: json['blurPlaceholder'] as String?,
      locked: json['locked'] as bool? ?? false,
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
    this.isPreview = false,
    this.accessReason,
    this.isFollowing = false,
    this.viewsCount,
    this.purchaseCount,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
    this.moderationStatus,
    this.processingStatus,
    this.uploadRewardStatus,
  });

  final String id;
  final String creatorId;
  final String creatorName;
  final String? creatorAvatarUrl;
  final MediaPresentation media;
  final String? caption;
  final String createdAt;
  final bool locked;
  final bool isPreview;
  final String? accessReason;
  final bool isFollowing;
  final int? viewsCount;
  final int? purchaseCount;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final String? moderationStatus;
  final String? processingStatus;
  final String? uploadRewardStatus;

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
      isPreview: json['isPreview'] as bool? ?? false,
      accessReason: json['accessReason'] as String?,
      isFollowing: json['isFollowing'] as bool? ?? false,
      viewsCount: json['viewsCount'] as int?,
      purchaseCount: json['purchaseCount'] as int?,
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      moderationStatus: json['moderationStatus'] as String?,
      processingStatus: json['processingStatus'] as String?,
      uploadRewardStatus: json['uploadRewardStatus'] as String?,
    );
  }

  MomentFeedItem copyWith({
    bool? locked,
    MediaPresentation? media,
    bool? isFollowing,
    bool? isPreview,
    String? accessReason,
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
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
      isPreview: isPreview ?? this.isPreview,
      accessReason: accessReason ?? this.accessReason,
      isFollowing: isFollowing ?? this.isFollowing,
      viewsCount: viewsCount,
      purchaseCount: purchaseCount,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      moderationStatus: moderationStatus,
      processingStatus: processingStatus,
      uploadRewardStatus: uploadRewardStatus,
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

class MomentLikeResult {
  const MomentLikeResult({
    required this.likesCount,
    required this.isLiked,
  });

  final int likesCount;
  final bool isLiked;

  factory MomentLikeResult.fromJson(Map<String, dynamic> json) {
    return MomentLikeResult(
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
    );
  }
}

class MomentShareInfo {
  const MomentShareInfo({
    required this.shareUrl,
    required this.deepLink,
    required this.playStoreUrl,
    required this.title,
    required this.thumbnailUrl,
  });

  final String shareUrl;
  final String deepLink;
  final String playStoreUrl;
  final String title;
  final String thumbnailUrl;

  factory MomentShareInfo.fromJson(Map<String, dynamic> json) {
    return MomentShareInfo(
      shareUrl: json['shareUrl'] as String? ?? '',
      deepLink: json['deepLink'] as String? ?? '',
      playStoreUrl: json['playStoreUrl'] as String? ?? '',
      title: json['title'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
    );
  }
}

class MomentComment {
  const MomentComment({
    required this.id,
    required this.authorUserId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.isCreator,
    this.isVipHighlighted = false,
    required this.text,
    required this.likesCount,
    required this.isLiked,
    this.parentCommentId,
    this.replies = const [],
    required this.createdAt,
  });

  final String id;
  final String authorUserId;
  final String authorName;
  final String? authorAvatarUrl;
  final bool isCreator;
  final bool isVipHighlighted;
  final String text;
  final int likesCount;
  final bool isLiked;
  final String? parentCommentId;
  final List<MomentComment> replies;
  final String createdAt;

  MomentComment copyWith({
    String? id,
    String? authorUserId,
    String? authorName,
    String? authorAvatarUrl,
    bool? isCreator,
    bool? isVipHighlighted,
    String? text,
    int? likesCount,
    bool? isLiked,
    String? parentCommentId,
    List<MomentComment>? replies,
    String? createdAt,
  }) {
    return MomentComment(
      id: id ?? this.id,
      authorUserId: authorUserId ?? this.authorUserId,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      isCreator: isCreator ?? this.isCreator,
      isVipHighlighted: isVipHighlighted ?? this.isVipHighlighted,
      text: text ?? this.text,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      replies: replies ?? this.replies,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory MomentComment.fromJson(Map<String, dynamic> json) {
    final rawReplies = json['replies'] as List? ?? const [];
    return MomentComment(
      id: json['id'] as String,
      authorUserId: json['authorUserId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? 'User',
      authorAvatarUrl: json['authorAvatarUrl'] as String?,
      isCreator: json['isCreator'] as bool? ?? false,
      isVipHighlighted: json['isVipHighlighted'] as bool? ?? false,
      text: json['text'] as String? ?? '',
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      parentCommentId: json['parentCommentId'] as String?,
      replies: rawReplies
          .map((e) => MomentComment.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class MomentCommentsPage {
  const MomentCommentsPage({
    required this.items,
    this.pinnedHighlightedComments = const [],
    this.nextCursor,
    this.hasMore = false,
  });

  final List<MomentComment> items;
  final List<MomentComment> pinnedHighlightedComments;
  final String? nextCursor;
  final bool hasMore;

  factory MomentCommentsPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List? ?? const [];
    final pinnedRaw = json['pinnedHighlightedComments'] as List? ?? const [];
    return MomentCommentsPage(
      items: raw
          .map((e) => MomentComment.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      pinnedHighlightedComments: pinnedRaw
          .map((e) => MomentComment.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}
