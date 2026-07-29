import 'package:equatable/equatable.dart';

class CreatorTasksResponse extends Equatable {
  /// Paid-call coins earned in the current weekly period.
  final double totalPaidCoins;
  final List<CreatorTask> tasks;

  /// When the current weekly period ends (targets reset).
  final DateTime? resetsAt;

  const CreatorTasksResponse({
    required this.totalPaidCoins,
    required this.tasks,
    this.resetsAt,
  });

  factory CreatorTasksResponse.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return 0.0;
    }

    // Accept either 'tasks' (standalone endpoint) or 'items' (dashboard endpoint)
    final tasksList = (json['tasks'] ?? json['items']) as List<dynamic>? ?? [];

    DateTime? resetsAt;
    if (json['resetsAt'] != null) {
      resetsAt = DateTime.tryParse(json['resetsAt'] as String);
    }

    // Prefer totalPaidCoins; fall back to legacy totalMinutes for old caches.
    final totalPaidCoins = json['totalPaidCoins'] != null
        ? toDouble(json['totalPaidCoins'])
        : toDouble(json['totalMinutes']);

    return CreatorTasksResponse(
      totalPaidCoins: totalPaidCoins,
      tasks: tasksList
          .map((task) => CreatorTask.fromJson(task as Map<String, dynamic>))
          .toList(),
      resetsAt: resetsAt,
    );
  }

  @override
  List<Object?> get props => [totalPaidCoins, tasks, resetsAt];
}

class CreatorTask extends Equatable {
  final String taskKey;
  final int thresholdPaidCoins;
  final int rewardCoins;
  final double progressPaidCoins;
  final bool isCompleted;
  final bool isClaimed;

  const CreatorTask({
    required this.taskKey,
    required this.thresholdPaidCoins,
    required this.rewardCoins,
    required this.progressPaidCoins,
    required this.isCompleted,
    required this.isClaimed,
  });

  factory CreatorTask.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return 0.0;
    }

    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return 0;
    }

    // Prefer paid-coin fields; fall back to legacy minute fields for old caches.
    final threshold = json['thresholdPaidCoins'] != null
        ? toInt(json['thresholdPaidCoins'])
        : toInt(json['thresholdMinutes']);
    final progress = json['progressPaidCoins'] != null
        ? toDouble(json['progressPaidCoins'])
        : toDouble(json['progressMinutes']);

    return CreatorTask(
      taskKey: json['taskKey'] as String,
      thresholdPaidCoins: threshold,
      rewardCoins: toInt(json['rewardCoins']),
      progressPaidCoins: progress,
      isCompleted: json['isCompleted'] as bool? ?? false,
      isClaimed: json['isClaimed'] as bool? ?? false,
    );
  }

  /// Progress percentage (0.0 to 1.0)
  double get progressPercentage {
    if (thresholdPaidCoins == 0) return 0.0;
    return (progressPaidCoins / thresholdPaidCoins).clamp(0.0, 1.0);
  }

  /// Can claim if completed and not yet claimed
  bool get canClaim => isCompleted && !isClaimed;

  @override
  List<Object?> get props => [
        taskKey,
        thresholdPaidCoins,
        rewardCoins,
        progressPaidCoins,
        isCompleted,
        isClaimed,
      ];
}
