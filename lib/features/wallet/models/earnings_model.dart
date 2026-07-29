import 'package:equatable/equatable.dart';

class CreatorEarnings extends Equatable {
  final double totalEarnings;
  final double freeCallEarnings;
  final double paidCallEarnings;
  final double totalMinutes;
  final int totalCalls;
  final double earningsPerMinute; // CURRENT rate (what I earn right now based on current price)
  final double? avgEarningsPerMinute; // Historical average (what I earned on average from past calls)
  final double? currentPrice; // Creator's current price per minute
  final double? creatorSharePercentage; // Creator's share (e.g., 0.30 for 30%)
  final List<CallEarning> calls;

  const CreatorEarnings({
    required this.totalEarnings,
    this.freeCallEarnings = 0,
    this.paidCallEarnings = 0,
    required this.totalMinutes,
    required this.totalCalls,
    required this.earningsPerMinute,
    this.avgEarningsPerMinute,
    this.currentPrice,
    this.creatorSharePercentage,
    required this.calls,
  });

  factory CreatorEarnings.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return 0.0;
    }

    final totalEarnings = toDouble(json['totalEarnings']);
    final totalMinutes = toDouble(json['totalMinutes']);
    final freeCallEarnings = toDouble(json['freeCallEarnings']);
    final paidCallEarnings = json['paidCallEarnings'] != null
        ? toDouble(json['paidCallEarnings'])
        : totalEarnings;

    // ⚠️ IMPORTANT: earningsPerMinute = CURRENT rate (what I earn right now)
    // avgEarningsPerMinute = Historical average (what I earned on average)
    // 
    // These differ because:
    // - Calls are billed with Math.ceil (short calls skew averages)
    // - Historical calls may use old prices
    // - Short calls may be overcharged due to Math.ceil rounding
    
    // Backend sends both fields separately
    final earningsPerMinute = json['earningsPerMinute'] != null
        ? toDouble(json['earningsPerMinute'])
        : (totalMinutes > 0 ? totalEarnings / totalMinutes : 0.0); // Fallback to average if current rate not available
    
    final avgEarningsPerMinute = json['avgEarningsPerMinute'] != null
        ? toDouble(json['avgEarningsPerMinute'])
        : (totalMinutes > 0 ? totalEarnings / totalMinutes : 0.0); // Historical average

    return CreatorEarnings(
      totalEarnings: totalEarnings,
      freeCallEarnings: freeCallEarnings,
      paidCallEarnings: paidCallEarnings,
      totalMinutes: totalMinutes,
      totalCalls: (json['totalCalls'] as int?) ?? 0,
      earningsPerMinute: earningsPerMinute,
      avgEarningsPerMinute: avgEarningsPerMinute,
      currentPrice: json['currentPrice'] != null ? toDouble(json['currentPrice']) : null,
      creatorSharePercentage: json['creatorSharePercentage'] != null ? toDouble(json['creatorSharePercentage']) : null,
      calls: (json['calls'] as List<dynamic>?)
              ?.map((call) => CallEarning.fromJson(call as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  /// Calculate the actual percentage based on current price and current earnings rate
  /// Returns the percentage (0-100) that creator earns at current rate
  int get calculatedPercentage {
    if (currentPrice != null && currentPrice! > 0) {
      return ((earningsPerMinute / currentPrice!) * 100).round();
    }
    // Fallback to standard 30% if price not available
    return 30;
  }

  @override
  List<Object?> get props => [
        totalEarnings,
        freeCallEarnings,
        paidCallEarnings,
        totalMinutes,
        totalCalls,
        earningsPerMinute,
        avgEarningsPerMinute,
        currentPrice,
        creatorSharePercentage,
        calls,
      ];
}

class CallEarning extends Equatable {
  final String callId;
  final String callerUsername;
  final int duration; // Duration in seconds
  final String durationFormatted;
  final double durationMinutes;
  final double earnings;
  final String? endedAt;

  const CallEarning({
    required this.callId,
    required this.callerUsername,
    required this.duration,
    required this.durationFormatted,
    required this.durationMinutes,
    required this.earnings,
    this.endedAt,
  });

  factory CallEarning.fromJson(Map<String, dynamic> json) {
    return CallEarning(
      callId: json['callId'] as String,
      callerUsername: json['callerUsername'] as String,
      duration: json['duration'] as int,
      durationFormatted: json['durationFormatted'] as String,
      durationMinutes: (json['durationMinutes'] as num).toDouble(),
      earnings: (json['earnings'] as num).toDouble(),
      endedAt: json['endedAt'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        callId,
        callerUsername,
        duration,
        durationFormatted,
        durationMinutes,
        earnings,
        endedAt,
      ];
}
