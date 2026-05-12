import 'package:equatable/equatable.dart';

import '../../../core/images/image_asset_view.dart';

class CallHistoryModel extends Equatable {
  final String id;
  final String callId;
  final String ownerUserId;
  final String otherUserId;
  final String? otherCreatorId; // Creator._id (only when other party is a creator)
  final String otherName;

  /// @deprecated Legacy avatar URL string. Prefer [otherAvatarAsset].
  final String? otherAvatar;

  /// Cloudflare avatar payload for the counterparty. Used by the recents list
  /// via [AppAvatar].
  final AvatarAssetView? otherAvatarAsset;

  final String otherFirebaseUid;
  final String ownerRole; // 'user' or 'creator'
  final String? direction; // 'incoming' | 'outgoing' (relative to owner)
  final int durationSeconds;
  final int coinsDeducted;
  final int coinsEarned;
  final DateTime createdAt;

  const CallHistoryModel({
    required this.id,
    required this.callId,
    required this.ownerUserId,
    required this.otherUserId,
    this.otherCreatorId,
    required this.otherName,
    this.otherAvatar,
    this.otherAvatarAsset,
    required this.otherFirebaseUid,
    required this.ownerRole,
    this.direction,
    required this.durationSeconds,
    required this.coinsDeducted,
    required this.coinsEarned,
    required this.createdAt,
  });

  /// The Mongo ID to use for billing (Creator._id preferred, User._id fallback).
  String get otherMongoIdForCall => otherCreatorId ?? otherUserId;

  factory CallHistoryModel.fromJson(Map<String, dynamic> json) {
    return CallHistoryModel(
      id: json['_id'] as String? ?? '',
      callId: json['callId'] as String? ?? '',
      ownerUserId: json['ownerUserId'] as String? ?? '',
      otherUserId: json['otherUserId'] as String? ?? '',
      otherCreatorId: json['otherCreatorId'] as String?,
      otherName: json['otherName'] as String? ?? 'Unknown',
      otherAvatar: json['otherAvatar'] is String
          ? json['otherAvatar'] as String?
          : null,
      otherAvatarAsset: AvatarAssetView.fromJson(
        json['otherAvatarAsset'] as Map<String, dynamic>?,
      ),
      otherFirebaseUid: json['otherFirebaseUid'] as String? ?? '',
      ownerRole: json['ownerRole'] as String? ?? 'user',
      direction: json['direction'] as String?,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      coinsDeducted: json['coinsDeducted'] as int? ?? 0,
      coinsEarned: json['coinsEarned'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  /// Format duration as "Xm Ys" or "Xs"
  String get formattedDuration {
    if (durationSeconds >= 60) {
      final minutes = durationSeconds ~/ 60;
      final seconds = durationSeconds % 60;
      return seconds > 0 ? '${minutes}m ${seconds}s' : '${minutes}m';
    }
    return '${durationSeconds}s';
  }

  /// Whether this record is outgoing relative to the owner.
  /// Prefer durable `direction`; fall back to legacy `ownerRole` heuristic for old rows.
  bool get isOutgoing => direction == 'outgoing' || (direction == null && ownerRole == 'user');

  @override
  List<Object?> get props => [id, callId, ownerUserId, otherUserId, otherCreatorId, direction, createdAt];
}
