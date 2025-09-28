import 'dart:convert';
import 'todo_model.dart';
import 'diary_models.dart';

class DailyProgress {
  final String date; // YYYY-MM-DD 형식
  final int totalTodos;
  final int completedTodos;
  final Map<String, int> partProgress;
  final DateTime recordedAt;

  DailyProgress({
    required this.date,
    required this.totalTodos,
    required this.completedTodos,
    required this.partProgress,
    required this.recordedAt,
  });

  factory DailyProgress.fromJson(String jsonString) {
    final data = jsonDecode(jsonString);
    return DailyProgress(
      date: data['date'] as String,
      totalTodos: data['totalTodos'] as int,
      completedTodos: data['completedTodos'] as int,
      partProgress: Map<String, int>.from(data['partProgress'] ?? {}),
      recordedAt: DateTime.parse(data['recordedAt']),
    );
  }

  factory DailyProgress.fromMap(Map<String, dynamic> data) {
    return DailyProgress(
      date: data['date'] as String,
      totalTodos: data['totalTodos'] as int,
      completedTodos: data['completedTodos'] as int,
      partProgress: Map<String, int>.from(data['partProgress'] ?? {}),
      recordedAt: DateTime.parse(data['recordedAt']),
    );
  }

  String toJson() => jsonEncode({
    'date': date,
    'totalTodos': totalTodos,
    'completedTodos': completedTodos,
    'partProgress': partProgress,
    'recordedAt': recordedAt.toIso8601String(),
  });

  Map<String, dynamic> toMap() => {
    'date': date,
    'totalTodos': totalTodos,
    'completedTodos': completedTodos,
    'partProgress': partProgress,
    'recordedAt': recordedAt.toIso8601String(),
  };

  double get completionRate => totalTodos > 0 ? completedTodos / totalTodos : 0.0;
}

class CompletedTask {
  final String todoId;
  final String title;
  final String category;
  final String? customCategory;
  final String part; // 기존 호환성
  final int priority;
  final String priorityName;
  final int progressPercentage;
  final bool isSubtask;
  final String? parentId;
  final int subtaskCount;
  final DateTime completedAt;
  final DateTime? dueDate;
  final Map<String, int>? dueTime;
  final int dueDateType;
  final String dueDateTypeName;
  final int notificationInterval;
  final String notificationIntervalName;
  final bool wasOverdue;
  final bool wasDueSoon;

  CompletedTask({
    required this.todoId,
    required this.title,
    required this.category,
    this.customCategory,
    required this.part,
    required this.priority,
    required this.priorityName,
    required this.progressPercentage,
    required this.isSubtask,
    this.parentId,
    required this.subtaskCount,
    required this.completedAt,
    this.dueDate,
    this.dueTime,
    required this.dueDateType,
    required this.dueDateTypeName,
    required this.notificationInterval,
    required this.notificationIntervalName,
    required this.wasOverdue,
    required this.wasDueSoon,
  });

  factory CompletedTask.fromJson(Map<String, dynamic> data) {
    final completedAt = data['completedAtKST'] != null
        ? DateTime.parse(data['completedAtKST'])
        : DateTime.parse(data['completedAt']);

    final dueDate = data['dueDate'] != null
        ? DateTime.parse(data['dueDate'])
        : null;
    
    return CompletedTask(
      todoId: data['todoId'] as String? ?? '',
      title: data['title'] as String? ?? 'Unknown',
      category: data['category'] as String? ?? data['part'] as String? ?? 'Unknown',
      customCategory: data['customCategory'] as String?,
      part: data['part'] as String? ?? 'Unknown',
      priority: data['priority'] as int? ?? 1,
      priorityName: data['priorityName'] as String? ?? '보통',
      progressPercentage: data['progressPercentage'] as int? ?? 0,
      isSubtask: data['isSubtask'] as bool? ?? false,
      parentId: data['parentId'] as String?,
      subtaskCount: data['subtaskCount'] as int? ?? 0,
      completedAt: completedAt,
      dueDate: dueDate,
      dueTime: data['dueTime'] != null 
          ? Map<String, int>.from(data['dueTime'])
          : null,
      dueDateType: data['dueDateType'] as int? ?? 0,
      dueDateTypeName: data['dueDateTypeName'] as String? ?? '마감일 없음',
      notificationInterval: data['notificationInterval'] as int? ?? 0,
      notificationIntervalName: data['notificationIntervalName'] as String? ?? '없음',
      wasOverdue: data['wasOverdue'] as bool? ?? (dueDate != null && completedAt.isAfter(dueDate)),
      wasDueSoon: data['wasDueSoon'] as bool? ?? false,
    );
  }

  String get displayCategory {
    if (category == '기타' && customCategory != null && customCategory!.isNotEmpty) {
      return customCategory!;
    }
    return category;
  }

  String get dueTimeDisplay {
    if (dueTime == null) return '';
    return '${dueTime!['hour']!.toString().padLeft(2, '0')}:${dueTime!['minute']!.toString().padLeft(2, '0')}';
  }
}

class CategoryPerformance {
  final String category;
  final int totalTasks;
  final int completedTasks;
  final int overdueTasks;
  final int onTimeTasks;
  final double completionRate;
  final double onTimeRate;
  final List<String> strengthAreas;
  final List<String> weaknessAreas;

  CategoryPerformance({
    required this.category,
    required this.totalTasks,
    required this.completedTasks,
    required this.overdueTasks,
    required this.onTimeTasks,
    required this.completionRate,
    required this.onTimeRate,
    required this.strengthAreas,
    required this.weaknessAreas,
  });
}

class WeeklyAnalysis {
  final DateTime weekStart;
  final DateTime weekEnd;
  final int totalCreated;
  final int totalCompleted;
  final int totalOverdue;
  final int totalOnTime;
  final Map<String, CategoryPerformance> categoryPerformance;
  final Map<Priority, int> priorityDistribution;
  final List<String> insights;
  final String personalizedAdvice;

  WeeklyAnalysis({
    required this.weekStart,
    required this.weekEnd,
    required this.totalCreated,
    required this.totalCompleted,
    required this.totalOverdue,
    required this.totalOnTime,
    required this.categoryPerformance,
    required this.priorityDistribution,
    required this.insights,
    required this.personalizedAdvice,
  });

  double get completionRate => totalCreated > 0 ? totalCompleted / totalCreated : 0.0;
  double get onTimeRate => totalCompleted > 0 ? totalOnTime / totalCompleted : 0.0;
  double get overdueRate => totalCreated > 0 ? totalOverdue / totalCreated : 0.0;
}

class UserAnalytics {
  final int totalDays;
  final int availableDays;
  final List<DailyProgress> dailyData;
  final double avgCompletionRate;
  final Map<String, double> partPerformance;
  final bool canRequestAnalysis;
  final DateTime? lastAnalysisDate;
  final int daysUntilNextAnalysis;
  final WeeklyAnalysis? weeklyAnalysis;

  UserAnalytics({
    required this.totalDays,
    required this.availableDays,
    required this.dailyData,
    required this.avgCompletionRate,
    required this.partPerformance,
    required this.canRequestAnalysis,
    this.lastAnalysisDate,
    required this.daysUntilNextAnalysis,
    this.weeklyAnalysis,
  });
}