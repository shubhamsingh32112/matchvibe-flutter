import 'package:equatable/equatable.dart';

import '../../../core/images/image_asset_view.dart';
import '../../../core/utils/api_json.dart';

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
    var ownerRole = readOptionalString(json['ownerRole']) ?? 'user';
    if (ownerRole != 'user' && ownerRole != 'creator') {
      ownerRole = 'user';
    }
    final dir = readOptionalString(json['direction']);
    final direction =
        dir == 'incoming' || dir == 'outgoing' ? dir : null;

    return CallHistoryModel(
      id: readIdString(json['_id']),
      callId: readOptionalString(json['callId']) ?? '',
      ownerUserId: readIdString(json['ownerUserId']),
      otherUserId: readIdString(json['otherUserId']),
      otherCreatorId: readId(json['otherCreatorId']),
      otherName: readOptionalString(json['otherName']) ?? 'Unknown',
      otherAvatar: json['otherAvatar'] is String
          ? json['otherAvatar'] as String?
          : null,
      otherAvatarAsset: AvatarAssetView.fromJson(
        readJsonMap(json['otherAvatarAsset']),
      ),
      otherFirebaseUid: readOptionalString(json['otherFirebaseUid']) ?? '',
      ownerRole: ownerRole,
      direction: direction,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      coinsDeducted: (json['coinsDeducted'] as num?)?.toInt() ?? 0,
      coinsEarned: (json['coinsEarned'] as num?)?.toInt() ?? 0,
      createdAt: readDateTimeWithFallback(json['createdAt']),
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
