import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../config/api_keys.dart';
import '../models/todo_model.dart';
import '../models/analysis_models.dart';
import '../utils/timezone_utils.dart';

class AIAnalysisService {
  static final AIAnalysisService _instance = AIAnalysisService._internal();
  factory AIAnalysisService() => _instance;
  AIAnalysisService._internal();

  GenerativeModel? _model;

  GenerativeModel get model {
    _model ??= GenerativeModel(
      model: 'gemini-1.5-pro',
      apiKey: ApiKeys.geminiApiKey,
    );
    return _model!;
  }

  void dispose() {
    _model = null;
  }

  // 하루 종료 시 일일 진행률을 Firestore에 저장
  Future<void> saveDailyProgress(String userId, List<Todo> todos) async {
    try {
      final now = TimeZoneUtils.kstNow;
      final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      final totalTodos = todos.length;
      final completedTodos = todos.where((t) => t.done).length;
      
      // 파트별 진행률 계산
      final partProgress = <String, int>{};
      for (final todo in todos.where((t) => t.done)) {
        partProgress[todo.part] = (partProgress[todo.part] ?? 0) + 1;
      }

      final dailyProgress = DailyProgress(
        date: dateKey,
        totalTodos: totalTodos,
        completedTodos: completedTodos,
        partProgress: partProgress,
        recordedAt: now,
      );

      // Firestore에 저장 (같은 날짜면 덮어쓰기)
      await FirebaseFirestore.instance
          .collection('daily_progress')
          .doc('${userId}_$dateKey')
          .set(dailyProgress.toFirestore());
    } catch (e) {
      print('일일 진행률 저장 실패: $e');
    }
  }

  Future<UserAnalytics> analyzeUserData(String userId) async {
    try {
      // 일일 진행률 데이터 조회 (userId로 필터링하기 위해 문서 ID 패턴 사용)
      final progressSnapshot = await FirebaseFirestore.instance
          .collection('daily_progress')
          .orderBy('recordedAt', descending: true)
          .get();

      // 클라이언트 측에서 userId 필터링
      final userDocs = progressSnapshot.docs.where((doc) => doc.id.startsWith('${userId}_')).toList();

      final dailyData = userDocs
          .map((doc) => DailyProgress.fromFirestore(doc.data()))
          .toList();

      // 마지막 AI 분석 시점 조회
      final lastAnalysisDoc = await FirebaseFirestore.instance
          .collection('ai_analysis_history')
          .doc(userId)
          .get();

      DateTime? lastAnalysisDate;
      if (lastAnalysisDoc.exists) {
        lastAnalysisDate = (lastAnalysisDoc.data()!['lastAnalysisDate'] as Timestamp).toDate();
      }

      // 분석 가능 여부 판단
      final canRequestAnalysis = _canRequestAnalysis(dailyData, lastAnalysisDate, userId);
      final daysUntilNext = _calculateDaysUntilNext(dailyData, lastAnalysisDate, userId);

      // 평균 완료율 계산
      final avgCompletionRate = dailyData.isEmpty 
          ? 0.0 
          : dailyData.map((d) => d.completionRate).reduce((a, b) => a + b) / dailyData.length;

      // 파트별 성과 계산
      final partPerformance = <String, double>{};
      if (dailyData.isNotEmpty) {
        final allParts = dailyData.expand((d) => d.partProgress.keys).toSet();
        for (final part in allParts) {
          final partDays = dailyData.where((d) => d.partProgress.containsKey(part)).toList();
          if (partDays.isNotEmpty) {
            final totalCompleted = partDays.map((d) => d.partProgress[part] ?? 0).reduce((a, b) => a + b);
            final avgPerDay = totalCompleted / partDays.length;
            partPerformance[part] = avgPerDay;
          }
        }
      }

      // 주간 분석 생성 (7일 이상 데이터가 있을 때)
      WeeklyAnalysis? weeklyAnalysis;
      if (dailyData.length >= 7) {
        weeklyAnalysis = await _generateWeeklyAnalysis(userId, dailyData);
      }

      return UserAnalytics(
        totalDays: dailyData.length,
        availableDays: dailyData.length,
        dailyData: dailyData,
        avgCompletionRate: avgCompletionRate,
        partPerformance: partPerformance,
        canRequestAnalysis: canRequestAnalysis,
        lastAnalysisDate: lastAnalysisDate,
        daysUntilNextAnalysis: daysUntilNext,
        weeklyAnalysis: weeklyAnalysis,
      );
    } catch (e) {
      throw Exception('데이터 분석 실패: $e');
    }
  }

  bool _canRequestAnalysis(List<DailyProgress> dailyData, DateTime? lastAnalysisDate, String userId) {
    // 관리자 계정은 항상 분석 가능
    if (userId == 'super@root.com' || FirebaseAuth.instance.currentUser?.email == 'super@root.com') {
      return true;
    }

    // 1. 최소 7일 데이터가 있어야 함
    if (dailyData.length < 7) return false;

    // 2. 마지막 분석이 없으면 가능
    if (lastAnalysisDate == null) return true;

    // 3. 마지막 분석 후 7일이 지났어야 함
    final daysSinceLastAnalysis = TimeZoneUtils.kstNow.difference(lastAnalysisDate).inDays;
    return daysSinceLastAnalysis >= 7;
  }

  int _calculateDaysUntilNext(List<DailyProgress> dailyData, DateTime? lastAnalysisDate, String userId) {
    // 관리자 계정은 항상 0일 (즉시 가능)
    if (userId == 'super@root.com' || FirebaseAuth.instance.currentUser?.email == 'super@root.com') {
      return 0;
    }

    if (dailyData.length < 7) {
      return 7 - dailyData.length;
    }

    if (lastAnalysisDate == null) return 0;

    final daysSinceLastAnalysis = TimeZoneUtils.kstNow.difference(lastAnalysisDate).inDays;
    return daysSinceLastAnalysis >= 7 ? 0 : 7 - daysSinceLastAnalysis;
  }

  // 7일간 상세 분석 생성
  Future<WeeklyAnalysis> _generateWeeklyAnalysis(String userId, List<DailyProgress> dailyData) async {
    final now = TimeZoneUtils.kstNow;
    final weekStart = now.subtract(const Duration(days: 7));
    
    // 지난 7일간의 완료된 태스크 데이터 조회
    final completedTasksSnapshot = await FirebaseFirestore.instance
        .collection('completed_tasks')
        .where('userId', isEqualTo: userId)
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .get();

    final completedTasks = completedTasksSnapshot.docs
        .map((doc) => CompletedTask.fromFirestore(doc.data()))
        .toList();

    // 통계 계산
    final totalCompleted = completedTasks.length;
    final totalOverdue = completedTasks.where((t) => t.wasOverdue).length;
    final totalOnTime = totalCompleted - totalOverdue;
    
    // 카테고리별 성과 분석
    final categoryStats = <String, CategoryPerformance>{};
    final categories = completedTasks.map((t) => t.part).toSet();
    
    for (final category in categories) {
      final categoryTasks = completedTasks.where((t) => t.part == category).toList();
      final categoryOverdue = categoryTasks.where((t) => t.wasOverdue).length;
      final categoryOnTime = categoryTasks.length - categoryOverdue;
      
      // 강약점 분석
      final completionRate = categoryTasks.length / totalCompleted;
      final onTimeRate = categoryTasks.isEmpty ? 0.0 : categoryOnTime / categoryTasks.length;
      
      List<String> strengths = [];
      List<String> weaknesses = [];
      
      if (completionRate > 0.2) strengths.add('높은 활동량');
      if (onTimeRate > 0.8) strengths.add('시간 관리 우수');
      if (onTimeRate < 0.6) weaknesses.add('마감일 관리 필요');
      if (completionRate < 0.1) weaknesses.add('활동량 부족');
      
      categoryStats[category] = CategoryPerformance(
        category: category,
        totalTasks: categoryTasks.length,
        completedTasks: categoryTasks.length,
        overdueTasks: categoryOverdue,
        onTimeTasks: categoryOnTime,
        completionRate: completionRate,
        onTimeRate: onTimeRate,
        strengthAreas: strengths,
        weaknessAreas: weaknesses,
      );
    }

    // 우선순위 분포 (현재 할 일에서)
    final priorityDistribution = <Priority, int>{};
    
    // AI 인사이트 생성
    final insights = _generateInsights(completedTasks, categoryStats);
    
    // 개인화된 조언 생성
    final personalizedAdvice = await _generatePersonalizedAdvice(
      totalCompleted, 
      totalOverdue, 
      categoryStats
    );

    return WeeklyAnalysis(
      weekStart: weekStart,
      weekEnd: now,
      totalCreated: totalCompleted, // 임시: 완료된 것으로 가정
      totalCompleted: totalCompleted,
      totalOverdue: totalOverdue,
      totalOnTime: totalOnTime,
      categoryPerformance: categoryStats,
      priorityDistribution: priorityDistribution,
      insights: insights,
      personalizedAdvice: personalizedAdvice,
    );
  }

  List<String> _generateInsights(List<CompletedTask> tasks, Map<String, CategoryPerformance> categoryStats) {
    final insights = <String>[];
    
    if (tasks.isEmpty) {
      insights.add('지난 7일간 완료한 태스크가 없습니다. 작은 목표부터 시작해보세요!');
      return insights;
    }
    
    // 완료율 분석
    final totalTasks = tasks.length;
    final overdueTasks = tasks.where((t) => t.wasOverdue).length;
    final onTimeRate = (totalTasks - overdueTasks) / totalTasks;
    
    if (onTimeRate > 0.8) {
      insights.add('📅 시간 관리가 뛰어납니다! ${(onTimeRate * 100).toInt()}%의 태스크를 시간 내에 완료했어요.');
    } else if (onTimeRate < 0.6) {
      insights.add('⏰ 마감일 관리에 주의가 필요합니다. ${overdueTasks}개 태스크가 늦었어요.');
    }
    
    // 가장 활발한 카테고리
    final mostActive = categoryStats.entries
        .reduce((a, b) => a.value.totalTasks > b.value.totalTasks ? a : b);
    insights.add('🏆 "${mostActive.key}" 카테고리에서 가장 활발했습니다! (${mostActive.value.totalTasks}개 완료)');
    
    // 개선이 필요한 카테고리
    final needsImprovement = categoryStats.entries
        .where((e) => e.value.onTimeRate < 0.6 && e.value.totalTasks > 1)
        .toList();
    
    if (needsImprovement.isNotEmpty) {
      insights.add('🎯 "${needsImprovement.first.key}" 카테고리의 시간 관리를 개선해보세요.');
    }
    
    return insights;
  }

  Future<String> _generatePersonalizedAdvice(
    int totalCompleted, 
    int totalOverdue, 
    Map<String, CategoryPerformance> categoryStats
  ) async {
    if (totalCompleted == 0) {
      return '''
🌟 새로운 시작을 응원합니다!

지난 주는 조용했지만, 이제 새롭게 시작할 때입니다. 
작은 목표부터 설정해서 성취감을 쌓아가세요!

💡 **추천 액션**:
• 오늘 할 수 있는 간단한 태스크 1개 만들기
• 카테고리를 선택해서 집중 영역 정하기
• 알림을 설정해서 꾸준한 습관 만들기
      ''';
    }
    
    final onTimeRate = (totalCompleted - totalOverdue) / totalCompleted;
    String advice = '';
    
    if (onTimeRate > 0.8) {
      advice = '''
🎉 **훌륭한 한 주였습니다!**

총 ${totalCompleted}개의 태스크를 완료하고, 대부분을 시간 내에 끝내셨네요!
이런 페이스를 유지하면서 더 큰 목표에 도전해보세요.
      ''';
    } else {
      advice = '''
💪 **개선의 여지가 있어요!**

총 ${totalCompleted}개 완료 중 ${totalOverdue}개가 늦었습니다.
마감일을 더 여유있게 설정하거나, 태스크를 작게 나눠보세요.
      ''';
    }
    
    // 카테고리별 조언 추가
    final strongCategory = categoryStats.entries
        .where((e) => e.value.onTimeRate > 0.8)
        .map((e) => e.key)
        .join(', ');
        
    final weakCategory = categoryStats.entries
        .where((e) => e.value.onTimeRate < 0.6)
        .map((e) => e.key)
        .join(', ');
    
    if (strongCategory.isNotEmpty) {
      advice += '\n\n🏅 **강점 영역**: $strongCategory\n이 분야의 노하우를 다른 영역에도 적용해보세요!';
    }
    
    if (weakCategory.isNotEmpty) {
      advice += '\n\n🎯 **개선 영역**: $weakCategory\n이 분야는 더 작은 단위로 나누거나 알림을 자주 설정해보세요.';
    }
    
    return advice;
  }

  Future<String> generatePersonalizedAdvice(UserAnalytics analytics, List<Todo> currentTodos) async {
    try {
      // 관리자 계정이 아닌 경우에만 제한 확인
      final isAdmin = FirebaseAuth.instance.currentUser?.email == 'super@root.com';
      if (!isAdmin && !analytics.canRequestAnalysis) {
        throw Exception('아직 AI 분석을 요청할 수 없습니다. ${analytics.daysUntilNextAnalysis}일 후에 다시 시도해주세요.');
      }

      final prompt = _buildAnalysisPrompt(analytics, currentTodos);
      
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      
      // 분석 완료 후 기록 저장
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _saveAnalysisHistory(user.uid);
      }
      
      return response.text ?? '조언을 생성할 수 없습니다.';
    } catch (e) {
      throw Exception('AI 조언 생성 실패: $e');
    }
  }

  Future<void> _saveAnalysisHistory(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('ai_analysis_history')
          .doc(userId)
          .set({
        'lastAnalysisDate': FieldValue.serverTimestamp(),
        'analysisCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      print('분석 기록 저장 실패: $e');
    }
  }

  String _buildAnalysisPrompt(UserAnalytics analytics, List<Todo> currentTodos) {
    final buffer = StringBuffer();
    buffer.writeln('당신은 개인 생산성 코치입니다. 다음 사용자의 ${analytics.totalDays}일간 데이터를 분석하여 개인화된 조언을 해주세요.');
    buffer.writeln('');
    buffer.writeln('【전체 성과 분석】');
    buffer.writeln('- 평균 완료율: ${(analytics.avgCompletionRate * 100).toStringAsFixed(1)}%');
    buffer.writeln('- 분석 기간: ${analytics.totalDays}일');
    buffer.writeln('');
    buffer.writeln('【파트별 평균 성과】');
    analytics.partPerformance.forEach((part, avg) {
      buffer.writeln('- $part: 일평균 ${avg.toStringAsFixed(1)}개 완료');
    });
    buffer.writeln('');
    buffer.writeln('【최근 일주일 트렌드】');
    final recentWeek = analytics.dailyData.take(7).toList();
    for (final day in recentWeek) {
      buffer.writeln('- ${day.date}: ${day.completedTodos}/${day.totalTodos} (${(day.completionRate * 100).toStringAsFixed(0)}%)');
    }
    buffer.writeln('');
    buffer.writeln('【현재 미완료 작업】');
    for (final todo in currentTodos.where((t) => !t.done)) {
      final dueText = todo.dueDate != null ? ' (마감: ${todo.dueDateDisplay})' : '';
      buffer.writeln('- ${todo.title} [${todo.category}] ${todo.priority.displayName}$dueText');
    }
    buffer.writeln('');
    buffer.writeln('위 데이터를 바탕으로:');
    buffer.writeln('1. 현재 생산성 패턴 분석');
    buffer.writeln('2. 강점과 개선점 도출');
    buffer.writeln('3. 구체적이고 실행 가능한 조언 제공');
    buffer.writeln('4. 다음 주 목표 제안');
    buffer.writeln('');
    buffer.writeln('친근하고 격려하는 톤으로 한국어로 답변해주세요.');
    
    return buffer.toString();
  }
}