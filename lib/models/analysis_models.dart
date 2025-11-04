import 'package:cloud_firestore/cloud_firestore.dart';
import 'todo_model.dart';

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

  factory DailyProgress.fromFirestore(Map<String, dynamic> data) {
    return DailyProgress(
      date: data['date'] as String,
      totalTodos: data['totalTodos'] as int,
      completedTodos: data['completedTodos'] as int,
      partProgress: Map<String, int>.from(data['partProgress'] ?? {}),
      recordedAt: (data['recordedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'date': date,
    'totalTodos': totalTodos,
    'completedTodos': completedTodos,
    'partProgress': partProgress,
    'recordedAt': FieldValue.serverTimestamp(),
  };

  double get completionRate => totalTodos > 0 ? completedTodos / totalTodos : 0.0;
}

class CompletedTask {
  final String title;
  final String part;
  final DateTime completedAt;
  final DateTime? dueDate;
  final bool wasOverdue;

  CompletedTask({
    required this.title,
    required this.part,
    required this.completedAt,
    this.dueDate,
    required this.wasOverdue,
  });

  factory CompletedTask.fromFirestore(Map<String, dynamic> data) {
    final completedAt = (data['completedAt'] as Timestamp).toDate();
    final dueDate = data['dueDate'] != null 
        ? (data['dueDate'] as Timestamp).toDate() 
        : null;
    
    return CompletedTask(
      title: data['title'] as String,
      part: data['part'] as String,
      completedAt: completedAt,
      dueDate: dueDate,
      wasOverdue: dueDate != null && completedAt.isAfter(dueDate),
    );
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