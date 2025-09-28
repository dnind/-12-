import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/todo_model.dart';
import '../models/analysis_models.dart';
import '../services/ai_analysis_service.dart';

class AIAdvicePage extends StatefulWidget {
  const AIAdvicePage({super.key});
  @override
  State<AIAdvicePage> createState() => _AIAdvicePageState();
}

class _AIAdvicePageState extends State<AIAdvicePage> {
  final AIAnalysisService _aiService = AIAnalysisService();
  UserAnalytics? _analytics;
  String? _advice;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAIAdvice();
  }

  Future<void> _loadAIAdvice() async {
    if (_loading) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 로컬 모드에서는 임시 사용자 사용
      const user = 'local_user';

      // 현재 사용자의 로컬 할 일 목록 불러오기
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('todos');
      List<Todo> currentTodos = [];
      if (raw != null) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        currentTodos = list.map(Todo.fromMap).toList();
      }

      // 사용자 데이터 분석
      final analytics = await _aiService.analyzeUserData(user);
      
      // AI 조언 생성
      final advice = await _aiService.generatePersonalizedAdvice(analytics, currentTodos);

      setState(() {
        _analytics = analytics;
        _advice = advice;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 조언'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAIAdvice,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('AI가 분석 중입니다...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('오류 발생: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAIAdvice,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_analytics == null || _advice == null) {
      return const Center(
        child: Text('데이터를 불러올 수 없습니다.'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 통계 요약
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📊 성과 요약',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('분석 기간: ${_analytics!.totalDays}일'),
                  Text('평균 완료율: ${(_analytics!.avgCompletionRate * 100).toStringAsFixed(1)}%'),
                  if (!_analytics!.canRequestAnalysis)
                    Text('다음 AI 분석: ${_analytics!.daysUntilNextAnalysis}일 후'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // AI 조언
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🤖 AI 조언',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_advice!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}