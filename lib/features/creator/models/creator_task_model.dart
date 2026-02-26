import 'package:equatable/equatable.dart';

class CreatorTasksResponse extends Equatable {
  final double totalMinutes;
  final List<CreatorTask> tasks;

  /// When the current daily period ends (tasks reset).
  /// `null` if the backend hasn't provided it yet (backwards compat).
  final DateTime? resetsAt;

  const CreatorTasksResponse({
    required this.totalMinutes,
    required this.tasks,
    this.resetsAt,
  });

  factory CreatorTasksResponse.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return 0.0;
    }

    // Accept either 'tasks' (standalone endpoint) or 'items' (dashboard endpoint)
    final tasksList = (json['tasks'] ?? json['items']) as List<dynamic>;

    DateTime? resetsAt;
    if (json['resetsAt'] != null) {
      resetsAt = DateTime.tryParse(json['resetsAt'] as String);
    }

    return CreatorTasksResponse(
      totalMinutes: _toDouble(json['totalMinutes']),
      tasks: tasksList
          .map((task) => CreatorTask.fromJson(task as Map<String, dynamic>))
          .toList(),
      resetsAt: resetsAt,
    );
  }

  @override
  List<Object?> get props => [totalMinutes, tasks, resetsAt];
}

class CreatorTask extends Equatable {
  final String taskKey;
  final int thresholdMinutes;
  final int rewardCoins;
  final double progressMinutes;
  final bool isCompleted;
  final bool isClaimed;

  const CreatorTask({
    required this.taskKey,
    required this.thresholdMinutes,
    required this.rewardCoins,
    required this.progressMinutes,
    required this.isCompleted,
    required this.isClaimed,
  });

  factory CreatorTask.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return 0.0;
    }

    return CreatorTask(
      taskKey: json['taskKey'] as String,
      thresholdMinutes: json['thresholdMinutes'] as int,
      rewardCoins: json['rewardCoins'] as int,
      progressMinutes: _toDouble(json['progressMinutes']),
      isCompleted: json['isCompleted'] as bool,
      isClaimed: json['isClaimed'] as bool,
    );
  }

  /// Progress percentage (0.0 to 1.0)
  double get progressPercentage {
    if (thresholdMinutes == 0) return 0.0;
    return (progressMinutes / thresholdMinutes).clamp(0.0, 1.0);
  }

  /// Can claim if completed and not yet claimed
  bool get canClaim => isCompleted && !isClaimed;

  @override
  List<Object?> get props => [
        taskKey,
        thresholdMinutes,
        rewardCoins,
        progressMinutes,
        isCompleted,
        isClaimed,
      ];
}
