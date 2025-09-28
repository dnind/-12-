import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  static const String adminEmail = 'super@root.com';
  
  // 현재 사용자가 관리자인지 확인
  static bool isAdmin() {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && user.email == adminEmail;
  }
  
  // 사용자 권한 확인 (Firestore 기반)
  static Future<bool> checkAdminRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    
    // 하드코딩된 관리자 이메일 확인
    if (user.email == adminEmail) return true;
    
    try {
      // Firestore에서 사용자 권한 확인
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        return data?['role'] == 'admin';
      }
    } catch (e) {
      print('권한 확인 실패: $e');
    }
    
    return false;
  }
  
  // 관리자 권한 부여 (최초 로그인 시)
  static Future<void> initializeAdminRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email != adminEmail) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'email': user.email,
        'role': 'admin',
        'displayName': '시스템 관리자',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('관리자 권한 초기화 실패: $e');
    }
  }
  
  // 모든 사용자 목록 가져오기
  static Future<List<UserData>> getAllUsers() async {
    if (!isAdmin()) {
      throw Exception('관리자 권한이 필요합니다.');
    }
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('lastLogin', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => UserData.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('사용자 목록 조회 실패: $e');
    }
  }
  
  // 전체 시스템 통계 가져오기
  static Future<SystemStats> getSystemStats() async {
    if (!isAdmin()) {
      throw Exception('관리자 권한이 필요합니다.');
    }
    
    try {
      // 전체 사용자 수
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      final totalUsers = usersSnapshot.size;
      
      // 오늘 활성 사용자 수
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final activeUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('lastLogin', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .get();
      final activeToday = activeUsersSnapshot.size;
      
      // 전체 할 일 통계
      final progressSnapshot = await FirebaseFirestore.instance
          .collection('daily_progress')
          .get();
      
      int totalTodos = 0;
      int completedTodos = 0;
      
      for (final doc in progressSnapshot.docs) {
        final data = doc.data();
        totalTodos += (data['totalTodos'] as int? ?? 0);
        completedTodos += (data['completedTodos'] as int? ?? 0);
      }
      
      // 전체 AI 분석 횟수
      final aiAnalysisSnapshot = await FirebaseFirestore.instance
          .collection('ai_analysis_history')
          .get();
      
      int totalAnalysis = 0;
      for (final doc in aiAnalysisSnapshot.docs) {
        totalAnalysis += (doc.data()['analysisCount'] as int? ?? 0);
      }
      
      return SystemStats(
        totalUsers: totalUsers,
        activeToday: activeToday,
        totalTodos: totalTodos,
        completedTodos: completedTodos,
        completionRate: totalTodos > 0 ? completedTodos / totalTodos : 0.0,
        totalAIAnalysis: totalAnalysis,
      );
    } catch (e) {
      throw Exception('시스템 통계 조회 실패: $e');
    }
  }
  
  // 특정 사용자의 상세 정보 가져오기
  static Future<UserDetail> getUserDetail(String userId) async {
    if (!isAdmin()) {
      throw Exception('관리자 권한이 필요합니다.');
    }
    
    try {
      // 사용자 기본 정보
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        throw Exception('사용자를 찾을 수 없습니다.');
      }
      
      final userData = UserData.fromFirestore(userDoc.data()!, userId);
      
      // 사용자의 일일 진행률
      final progressSnapshot = await FirebaseFirestore.instance
          .collection('daily_progress')
          .where(FieldPath.documentId, whereIn: [userId])
          .orderBy('recordedAt', descending: true)
          .limit(30)
          .get();
      
      final dailyProgress = progressSnapshot.docs
          .map((doc) => doc.data())
          .toList();
      
      // AI 분석 이력
      final aiDoc = await FirebaseFirestore.instance
          .collection('ai_analysis_history')
          .doc(userId)
          .get();
      
      final aiAnalysisCount = aiDoc.exists 
          ? (aiDoc.data()!['analysisCount'] as int? ?? 0)
          : 0;
      
      final lastAnalysisDate = aiDoc.exists && aiDoc.data()!['lastAnalysisDate'] != null
          ? (aiDoc.data()!['lastAnalysisDate'] as Timestamp).toDate()
          : null;
      
      return UserDetail(
        userData: userData,
        recentProgress: dailyProgress,
        aiAnalysisCount: aiAnalysisCount,
        lastAnalysisDate: lastAnalysisDate,
      );
    } catch (e) {
      throw Exception('사용자 상세 정보 조회 실패: $e');
    }
  }
  
  // 사용자 역할 변경
  static Future<void> updateUserRole(String userId, String newRole) async {
    if (!isAdmin()) {
      throw Exception('관리자 권한이 필요합니다.');
    }
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'role': newRole,
        'roleUpdatedAt': FieldValue.serverTimestamp(),
        'roleUpdatedBy': FirebaseAuth.instance.currentUser?.uid,
      });
    } catch (e) {
      throw Exception('사용자 역할 변경 실패: $e');
    }
  }
  
  // 시스템 공지사항 발송
  static Future<void> sendSystemNotification(String title, String message) async {
    if (!isAdmin()) {
      throw Exception('관리자 권한이 필요합니다.');
    }
    
    try {
      await FirebaseFirestore.instance.collection('system_notifications').add({
        'title': title,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'isActive': true,
      });
    } catch (e) {
      throw Exception('공지사항 발송 실패: $e');
    }
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
  
  UserData({
    required this.userId,
    required this.email,
    this.displayName,
    required this.role,
    this.createdAt,
    this.lastLogin,
  });
  
  factory UserData.fromFirestore(Map<String, dynamic> data, String userId) {
    return UserData(
      userId: userId,
      email: data['email'] as String? ?? 'Unknown',
      displayName: data['displayName'] as String?,
      role: data['role'] as String? ?? 'user',
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      lastLogin: data['lastLogin'] != null
          ? (data['lastLogin'] as Timestamp).toDate()
          : null,
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