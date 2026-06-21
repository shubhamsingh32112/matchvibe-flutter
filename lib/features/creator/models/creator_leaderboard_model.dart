import 'package:equatable/equatable.dart';

class CreatorLeaderboardSummary extends Equatable {
  final int? rank;
  final int totalCreators;
  final String period;
  final String sort;
  final int topRewardCoins;
  final int topRewardRank;

  const CreatorLeaderboardSummary({
    required this.rank,
    required this.totalCreators,
    required this.period,
    required this.sort,
    required this.topRewardCoins,
    required this.topRewardRank,
  });

  factory CreatorLeaderboardSummary.fromJson(Map<String, dynamic> json) {
    return CreatorLeaderboardSummary(
      rank: (json['rank'] as num?)?.toInt(),
      totalCreators: (json['totalCreators'] as num?)?.toInt() ?? 0,
      period: json['period'] as String? ?? '30d',
      sort: json['sort'] as String? ?? 'earnings',
      topRewardCoins: (json['topRewardCoins'] as num?)?.toInt() ?? 5000,
      topRewardRank: (json['topRewardRank'] as num?)?.toInt() ?? 10,
    );
  }

  @override
  List<Object?> get props =>
      [rank, totalCreators, period, sort, topRewardCoins, topRewardRank];
}

class CreatorLeaderboardRow extends Equatable {
  final int rank;
  final String? creatorId;
  final String hostUserId;
  final String hostName;
  final String? avatarUrl;
  final int callCount;
  final double talkMinutes;
  final int earningsCoins;
  final int followerCount;

  const CreatorLeaderboardRow({
    required this.rank,
    required this.creatorId,
    required this.hostUserId,
    required this.hostName,
    required this.avatarUrl,
    required this.callCount,
    required this.talkMinutes,
    required this.earningsCoins,
    required this.followerCount,
  });

  factory CreatorLeaderboardRow.fromJson(Map<String, dynamic> json) {
    return CreatorLeaderboardRow(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      creatorId: json['creatorId'] as String?,
      hostUserId: json['hostUserId'] as String? ?? '',
      hostName: json['hostName'] as String? ?? 'Creator',
      avatarUrl: json['avatarUrl'] as String?,
      callCount: (json['callCount'] as num?)?.toInt() ?? 0,
      talkMinutes: (json['talkMinutes'] as num?)?.toDouble() ?? 0,
      earningsCoins: (json['earningsCoins'] as num?)?.toInt() ?? 0,
      followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [rank, creatorId, hostUserId, hostName, avatarUrl, callCount, talkMinutes, earningsCoins, followerCount];
}

class CreatorLeaderboardResponse extends Equatable {
  final String period;
  final String sort;
  final List<CreatorLeaderboardRow> rows;

  const CreatorLeaderboardResponse({
    required this.period,
    required this.sort,
    required this.rows,
  });

  factory CreatorLeaderboardResponse.fromJson(Map<String, dynamic> json) {
    final rowsJson = json['rows'] as List<dynamic>? ?? [];
    return CreatorLeaderboardResponse(
      period: json['period'] as String? ?? '30d',
      sort: json['sort'] as String? ?? 'earnings',
      rows: rowsJson
          .map((e) => CreatorLeaderboardRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [period, sort, rows];
}
