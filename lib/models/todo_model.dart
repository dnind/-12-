import 'package:flutter/material.dart';
import '../utils/timezone_utils.dart';

enum Priority {
  low,      // 낮음 (회색)
  medium,   // 보통 (파란색)
  high,     // 높음 (주황색)
  urgent    // 긴급 (빨간색)
}

extension PriorityExtension on Priority {
  String get displayName {
    switch (this) {
      case Priority.low: return '낮음';
      case Priority.medium: return '보통';
      case Priority.high: return '높음';
      case Priority.urgent: return '긴급';
    }
  }

  Color get color {
    switch (this) {
      case Priority.low: return Colors.grey;
      case Priority.medium: return Colors.blue;
      case Priority.high: return Colors.orange;
      case Priority.urgent: return Colors.red;
    }
  }

  int get sortOrder {
    switch (this) {
      case Priority.urgent: return 4;
      case Priority.high: return 3;
      case Priority.medium: return 2;
      case Priority.low: return 1;
    }
  }
}

enum NotificationInterval {
  none,
  hourly,
  every3Hours,
  every6Hours,
  every12Hours,
  daily,
  weekly,
  monthly,
  every6Months,
  yearly,
}

extension NotificationIntervalExtension on NotificationInterval {
  String get displayName {
    switch (this) {
      case NotificationInterval.none: return '없음';
      case NotificationInterval.hourly: return '1시간마다';
      case NotificationInterval.every3Hours: return '3시간마다';
      case NotificationInterval.every6Hours: return '6시간마다';
      case NotificationInterval.every12Hours: return '12시간마다';
      case NotificationInterval.daily: return '매일';
      case NotificationInterval.weekly: return '매주';
      case NotificationInterval.monthly: return '매월';
      case NotificationInterval.every6Months: return '6개월마다';
      case NotificationInterval.yearly: return '매년';
    }
  }

  Duration? get duration {
    switch (this) {
      case NotificationInterval.none: return null;
      case NotificationInterval.hourly: return const Duration(hours: 1);
      case NotificationInterval.every3Hours: return const Duration(hours: 3);
      case NotificationInterval.every6Hours: return const Duration(hours: 6);
      case NotificationInterval.every12Hours: return const Duration(hours: 12);
      case NotificationInterval.daily: return const Duration(days: 1);
      case NotificationInterval.weekly: return const Duration(days: 7);
      case NotificationInterval.monthly: return const Duration(days: 30);
      case NotificationInterval.every6Months: return const Duration(days: 180);
      case NotificationInterval.yearly: return const Duration(days: 365);
    }
  }
}

enum DueDateType {
  none,      // 마감일 없음
  date,      // 날짜만
  dateTime   // 날짜 + 시간
}

extension DueDateTypeExtension on DueDateType {
  String get displayName {
    switch (this) {
      case DueDateType.none: return '마감일 없음';
      case DueDateType.date: return '날짜만';
      case DueDateType.dateTime: return '날짜 + 시간';
    }
  }
}

class Todo {
  final String id;
  String title;
  String part;  // 기존 호환성을 위해 유지
  String category;  // 새로운 카테고리 시스템
  String? customCategory;  // '기타' 카테고리일 때 사용자 정의 내용
  DateTime? dueDate;
  TimeOfDay? dueTime;  // 마감 시간 (선택사항)
  DueDateType dueDateType;  // 마감일 타입
  bool done;
  Priority priority;
  int progressPercentage;
  String? parentId;
  List<String> subtaskIds;
  
  // 알림 관련 필드
  NotificationInterval notificationInterval;
  DateTime? lastNotificationTime;
  DateTime? nextNotificationTime;

  Todo({
    required this.id,
    required this.title,
    this.part = '일반',  // 기존 호환성
    this.category = '개인',
    this.customCategory,
    this.dueDate,
    this.dueTime,
    this.dueDateType = DueDateType.none,
    this.done = false,
    this.priority = Priority.medium,
    this.progressPercentage = 0,
    this.parentId,
    List<String>? subtaskIds,
    this.notificationInterval = NotificationInterval.none,
    this.lastNotificationTime,
    this.nextNotificationTime,
  }) : subtaskIds = subtaskIds ?? [] {
    // part를 category로 마이그레이션 (기존 데이터 호환성)
    if (part != '일반' && category == '개인') {
      category = part;
    }
  }

  factory Todo.fromMap(Map<String, dynamic> m) => Todo(
    id: m['id'] as String,
    title: m['title'] as String,
    part: m['part'] as String? ?? '일반',
    category: m['category'] as String? ?? (m['part'] as String? ?? '개인'),
    customCategory: m['customCategory'] as String?,
    dueDate: m['dueDate'] != null ? DateTime.tryParse(m['dueDate']) : null,
    dueTime: m['dueTime'] != null ? TimeOfDay(
      hour: m['dueTime']['hour'] as int,
      minute: m['dueTime']['minute'] as int,
    ) : null,
    dueDateType: DueDateType.values[m['dueDateType'] as int? ?? DueDateType.none.index],
    done: m['done'] as bool? ?? false,
    priority: Priority.values[m['priority'] as int? ?? Priority.medium.index],
    progressPercentage: m['progressPercentage'] as int? ?? 0,
    parentId: m['parentId'] as String?,
    subtaskIds: List<String>.from(m['subtaskIds'] ?? []),
    notificationInterval: NotificationInterval.values[m['notificationInterval'] as int? ?? NotificationInterval.none.index],
    lastNotificationTime: m['lastNotificationTime'] != null ? DateTime.tryParse(m['lastNotificationTime']) : null,
    nextNotificationTime: m['nextNotificationTime'] != null ? DateTime.tryParse(m['nextNotificationTime']) : null,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'part': part,  // 기존 호환성
    'category': category,
    'customCategory': customCategory,
    'dueDate': dueDate?.toIso8601String(),
    'dueTime': dueTime != null ? {
      'hour': dueTime!.hour,
      'minute': dueTime!.minute,
    } : null,
    'dueDateType': dueDateType.index,
    'done': done,
    'priority': priority.index,
    'progressPercentage': progressPercentage,
    'parentId': parentId,
    'subtaskIds': subtaskIds,
    'notificationInterval': notificationInterval.index,
    'lastNotificationTime': lastNotificationTime?.toIso8601String(),
    'nextNotificationTime': nextNotificationTime?.toIso8601String(),
  };

  bool get isSubtask => parentId != null;
  bool get hasSubtasks => subtaskIds.isNotEmpty;
  
  String get displayCategory {
    if (category == '기타' && customCategory != null && customCategory!.isNotEmpty) {
      return customCategory!;
    }
    return category;
  }

  DateTime? get fullDueDateTime {
    if (dueDate == null) return null;
    if (dueTime == null || dueDateType != DueDateType.dateTime) return dueDate;
    
    return DateTime(
      dueDate!.year,
      dueDate!.month,
      dueDate!.day,
      dueTime!.hour,
      dueTime!.minute,
    );
  }

  bool get isOverdue {
    final deadline = fullDueDateTime;
    if (deadline == null || done) return false;
    return TimeZoneUtils.kstNow.isAfter(deadline);
  }

  bool get isDueSoon {
    final deadline = fullDueDateTime;
    if (deadline == null || done) return false;
    
    final now = TimeZoneUtils.kstNow;
    final timeDiff = deadline.difference(now);
    
    // 24시간 이내면 곧 마감
    return timeDiff.inHours <= 24 && timeDiff.inHours > 0;
  }

  String get dueDateDisplay {
    switch (dueDateType) {
      case DueDateType.none:
        return '마감일 없음';
      case DueDateType.date:
        return dueDate != null ? _formatDate(dueDate!) : '마감일 없음';
      case DueDateType.dateTime:
        if (dueDate != null && dueTime != null) {
          return '${_formatDate(dueDate!)} ${_formatTime(dueTime!)}';
        }
        return dueDate != null ? _formatDate(dueDate!) : '마감일 없음';
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}