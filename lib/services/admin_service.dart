import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/todo_model.dart';
import '../models/analysis_models.dart';

class AdminService {
  static const String adminEmail = 'super@root.com';

  // 현재 사용자가 관리자인지 확인 (로컬 모드에서는 항상 true)
  static bool isAdmin() {
    return true; // 로컬 모드에서는 모든 사용자가 관리자
  }

  // 사용자 권한 확인 (로컬 기반)
  static Future<bool> checkAdminRole() async {
    return true;
  }

  // 관리자 권한 초기화 (로컬 기반)
  static Future<void> initializeAdminRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_initialized', DateTime.now().toIso8601String());
  }

  // 모든 사용자 목록 가져오기 (로컬 기반)
  static Future<List<UserData>> getAllUsers() async {
    if (!isAdmin()) {
      throw Exception('관리자 권한이 필요합니다.');
    }

    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getStringList('users') ?? [];

    if (usersJson.isEmpty) {
      // 기본 사용자 생성
      final defaultUser = UserData(
        userId: 'local_user',
        email: 'local@user.com',
        displayName: '로컬 사용자',
        role: 'admin',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );
      await _saveUser(defaultUser);
      return [defaultUser];
    }

    return usersJson.map((json) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return UserData.fromJson(data);
    }).toList();
  }

  // 전체 시스템 통계 가져오기 (로컬 기반)
  static Future<SystemStats> getSystemStats() async {
    if (!isAdmin()) {
      throw Exception('관리자 권한이 필요합니다.');
    }

    final prefs = await SharedPreferences.getInstance();

    // 사용자 통계
    final users = await getAllUsers();
    final totalUsers = users.length;
    final activeToday = users.where((user) {
      if (user.lastLogin == null) return false;
      final today = DateTime.now();
      final loginDate = user.lastLogin!;
      return loginDate.year == today.year &&
             loginDate.month == today.month &&
             loginDate.day == today.day;
    }).length;

    // 할 일 통계
    final todosJson = prefs.getString('todos');
    int totalTodos = 0;
    int completedTodos = 0;

    if (todosJson != null) {
      final todosList = (jsonDecode(todosJson) as List).cast<Map<String, dynamic>>();
      totalTodos = todosList.length;
      completedTodos = todosList.where((todo) => todo['isCompleted'] == true).length;
    }

    // AI 분석 통계
    final aiAnalysisJson = prefs.getStringList('ai_analysis_history') ?? [];
    final totalAIAnalysis = aiAnalysisJson.length;

    return SystemStats(
      totalUsers: totalUsers,
      activeToday: activeToday,
      totalTodos: totalTodos,
      completedTodos: completedTodos,
      completionRate: totalTodos > 0 ? completedTodos / totalTodos : 0.0,
      totalAIAnalysis: totalAIAnalysis,
    );
  }

  // 특정 사용자의 상세 정보 가져오기 (로컬 기반)
  static Future<UserDetail> getUserDetail(String userId) async {
    if (!isAdmin()) {
      throw Exception('관리자 권한이 필요합니다.');
    }

    final users = await getAllUsers();
    final user = users.where((u) => u.userId == userId).firstOrNull;

    if (user == null) {
      throw Exception('사용자를 찾을 수 없습니다.');
    }

    // 일일 진행률 가져오기
    final prefs = await SharedPreferences.getInstance();
    final progressJson = prefs.getStringList('daily_progress_$userId') ?? [];
    final recentProgress = progressJson.take(30).map((json) {
      return jsonDecode(json) as Map<String, dynamic>;
    }).toList();

    // AI 분석 이력
    final aiHistoryJson = prefs.getStringList('ai_analysis_history_$userId') ?? [];
    final aiAnalysisCount = aiHistoryJson.length;

    DateTime? lastAnalysisDate;
    if (aiHistoryJson.isNotEmpty) {
      final lastAnalysis = jsonDecode(aiHistoryJson.last) as Map<String, dynamic>;
      lastAnalysisDate = DateTime.parse(lastAnalysis['date']);
    }

    return UserDetail(
      userData: user,
      recentProgress: recentProgress,
      aiAnalysisCount: aiAnalysisCount,
      lastAnalysisDate: lastAnalysisDate,
    );
  }

  // 사용자 역할 변경 (로컬 기반)
  static Future<void> updateUserRole(String userId, String newRole) async {
    if (!isAdmin()) {
      throw Exception('관리자 권한이 필요합니다.');
    }

    final users = await getAllUsers();
    final userIndex = users.indexWhere((u) => u.userId == userId);

    if (userIndex == -1) {
      throw Exception('사용자를 찾을 수 없습니다.');
    }

    users[userIndex] = users[userIndex].copyWith(
      role: newRole,
      roleUpdatedAt: DateTime.now(),
    );

    await _saveAllUsers(users);
  }

  // 시스템 공지사항 발송 (로컬 기반)
  static Future<void> sendSystemNotification(String title, String message) async {
    if (!isAdmin()) {
      throw Exception('관리자 권한이 필요합니다.');
    }

    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getStringList('system_notifications') ?? [];

    final notification = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'message': message,
      'createdAt': DateTime.now().toIso8601String(),
      'createdBy': 'local_admin',
      'isActive': true,
    };

    notificationsJson.add(jsonEncode(notification));
    await prefs.setStringList('system_notifications', notificationsJson);
  }

  // 일일 진행률 저장 (로컬 기반)
  static Future<void> saveDailyProgress(String userId, List<Todo> todos) async {
    final prefs = await SharedPreferences.getInstance();
    final progressKey = 'daily_progress_$userId';
    final progressJson = prefs.getStringList(progressKey) ?? [];

    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final completedTodos = todos.where((t) => t.done).length;
    final progress = {
      'date': dateKey,
      'totalTodos': todos.length,
      'completedTodos': completedTodos,
      'recordedAt': DateTime.now().toIso8601String(),
    };

    // 같은 날짜의 기존 기록 제거
    progressJson.removeWhere((json) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return data['date'] == dateKey;
    });

    progressJson.add(jsonEncode(progress));
    await prefs.setStringList(progressKey, progressJson);
  }

  // AI 분석 이력 저장 (로컬 기반)
  static Future<void> saveAIAnalysisHistory(String userId, String analysisType) async {
    final prefs = await SharedPreferences.getInstance();
    final historyKey = 'ai_analysis_history_$userId';
    final historyJson = prefs.getStringList(historyKey) ?? [];

    final analysis = {
      'type': analysisType,
      'date': DateTime.now().toIso8601String(),
      'userId': userId,
    };

    historyJson.add(jsonEncode(analysis));
    await prefs.setStringList(historyKey, historyJson);
  }

  // 사용자 저장 헬퍼 메서드
  static Future<void> _saveUser(UserData user) async {
    final users = await getAllUsers();
    final existingIndex = users.indexWhere((u) => u.userId == user.userId);

    if (existingIndex != -1) {
      users[existingIndex] = user;
    } else {
      users.add(user);
    }

    await _saveAllUsers(users);
  }

  // 모든 사용자 저장 헬퍼 메서드
  static Future<void> _saveAllUsers(List<UserData> users) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = users.map((user) => jsonEncode(user.toJson())).toList();
    await prefs.setStringList('users', usersJson);
  }
}

// 데이터 모델들
class UserData {
  final String userId;
  final String email;
  final String? displayName;
  final String role;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  final DateTime? roleUpdatedAt;

  UserData({
    required this.userId,
    required this.email,
    this.displayName,
    required this.role,
    this.createdAt,
    this.lastLogin,
    this.roleUpdatedAt,
  });

  factory UserData.fromJson(Map<String, dynamic> data) {
    return UserData(
      userId: data['userId'] as String,
      email: data['email'] as String? ?? 'Unknown',
      displayName: data['displayName'] as String?,
      role: data['role'] as String? ?? 'user',
      createdAt: data['createdAt'] != null ? DateTime.parse(data['createdAt']) : null,
      lastLogin: data['lastLogin'] != null ? DateTime.parse(data['lastLogin']) : null,
      roleUpdatedAt: data['roleUpdatedAt'] != null ? DateTime.parse(data['roleUpdatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'email': email,
      'displayName': displayName,
      'role': role,
      'createdAt': createdAt?.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
      'roleUpdatedAt': roleUpdatedAt?.toIso8601String(),
    };
  }

  UserData copyWith({
    String? userId,
    String? email,
    String? displayName,
    String? role,
    DateTime? createdAt,
    DateTime? lastLogin,
    DateTime? roleUpdatedAt,
  }) {
    return UserData(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      roleUpdatedAt: roleUpdatedAt ?? this.roleUpdatedAt,
    );
  }
}

class SystemStats {
  final int totalUsers;
  final int activeToday;
  final int totalTodos;
  final int completedTodos;
  final double completionRate;
  final int totalAIAnalysis;

  SystemStats({
    required this.totalUsers,
    required this.activeToday,
    required this.totalTodos,
    required this.completedTodos,
    required this.completionRate,
    required this.totalAIAnalysis,
  });
}

class UserDetail {
  final UserData userData;
  final List<Map<String, dynamic>> recentProgress;
  final int aiAnalysisCount;
  final DateTime? lastAnalysisDate;

  UserDetail({
    required this.userData,
    required this.recentProgress,
    required this.aiAnalysisCount,
    this.lastAnalysisDate,
  });
}