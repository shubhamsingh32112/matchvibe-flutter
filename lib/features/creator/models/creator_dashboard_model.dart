import 'package:equatable/equatable.dart';
import '../../wallet/models/earnings_model.dart';
import 'creator_task_model.dart';

/// Consolidated creator dashboard data returned by GET /creator/dashboard.
///
/// This is the single source of truth for all creator-facing data:
/// - Earnings summary + recent calls (all-time)
/// - Today's earnings (current daily period)
/// - Task progress
/// - Coin balance
/// - Creator profile info
class CreatorDashboard extends Equatable {
  final CreatorEarnings earnings;
  final TodayEarnings todayEarnings;
  final CreatorTasksResponse tasks;
  final int coins;
  final CreatorProfileSummary creatorProfile;

  const CreatorDashboard({
    required this.earnings,
    required this.todayEarnings,
    required this.tasks,
    required this.coins,
    required this.creatorProfile,
  });

  factory CreatorDashboard.fromJson(Map<String, dynamic> json) {
    final earningsJson = json['earnings'] as Map<String, dynamic>;
    final tasksJson = json['tasks'] as Map<String, dynamic>;
    final profileJson = json['creatorProfile'] as Map<String, dynamic>;

    // todayEarnings may be absent in older API responses — default to zeroes
    final todayJson = json['todayEarnings'] as Map<String, dynamic>?;

    return CreatorDashboard(
      earnings: CreatorEarnings.fromJson(earningsJson),
      todayEarnings: todayJson != null
          ? TodayEarnings.fromJson(todayJson)
          : const TodayEarnings(totalEarnings: 0, totalMinutes: 0, totalCalls: 0),
      tasks: CreatorTasksResponse.fromJson(tasksJson),
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      creatorProfile: CreatorProfileSummary.fromJson(profileJson),
    );
  }

  @override
  List<Object?> get props => [earnings, todayEarnings, tasks, coins, creatorProfile];
}

/// Today's earnings summary for the current daily period.
class TodayEarnings extends Equatable {
  final double totalEarnings;
  final double totalMinutes;
  final int totalCalls;

  const TodayEarnings({
    required this.totalEarnings,
    required this.totalMinutes,
    required this.totalCalls,
  });

  factory TodayEarnings.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return 0.0;
    }

    return TodayEarnings(
      totalEarnings: _toDouble(json['totalEarnings']),
      totalMinutes: _toDouble(json['totalMinutes']),
      totalCalls: (json['totalCalls'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [totalEarnings, totalMinutes, totalCalls];
}

class CreatorProfileSummary extends Equatable {
  final String id;
  final String name;
  final double price;
  final bool isOnline;

  const CreatorProfileSummary({
    required this.id,
    required this.name,
    required this.price,
    required this.isOnline,
  });

  factory CreatorProfileSummary.fromJson(Map<String, dynamic> json) {
    return CreatorProfileSummary(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      isOnline: json['isOnline'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, name, price, isOnline];
}
