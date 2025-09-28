import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/todo_model.dart';
import '../models/analysis_models.dart';
import '../services/ai_analysis_service.dart';

class AIInsightsTab extends StatefulWidget {
  final AIAnalysisService aiService;
  final List<Todo> todos;
  
  const AIInsightsTab({super.key, required this.aiService, required this.todos});
  
  @override
  State<AIInsightsTab> createState() => _AIInsightsTabState();
}

class _AIInsightsTabState extends State<AIInsightsTab> {
  UserAnalytics? _analytics;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final analytics = await widget.aiService.analyzeUserData(user.uid);
        setState(() => _analytics = analytics);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('오류 발생: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAnalytics,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_analytics == null) {
      return const Center(
        child: Text('분석 데이터를 불러올 수 없습니다.'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 현재 상황 요약
          _buildCurrentStatusCard(),
          const SizedBox(height: 16),
          
          // 분석 가능 여부
          _buildAnalysisStatusCard(),
          const SizedBox(height: 16),
          
          // 주간 분석 (있을 경우)
          if (_analytics!.weeklyAnalysis != null) ...[
            _buildWeeklyAnalysisCard(),
            const SizedBox(height: 16),
          ],
          
          // 파트별 성과
          if (_analytics!.partPerformance.isNotEmpty) ...[
            _buildPartPerformanceCard(),
            const SizedBox(height: 16),
          ],
          
          // AI 조언 요청 버튼
          _buildRequestAdviceButton(),
        ],
      ),
    );
  }

  Widget _buildCurrentStatusCard() {
    final activeTodos = widget.todos.where((t) => !t.done).length;
    final completedTodos = widget.todos.where((t) => t.done).length;
    final overdueTodos = widget.todos.where((t) => t.isOverdue && !t.done).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.dashboard, color: Colors.blue),
                SizedBox(width: 8),
                Text('현재 현황', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusItem('활성', activeTodos, Colors.blue),
                _buildStatusItem('완료', completedTodos, Colors.green),
                _buildStatusItem('초과', overdueTodos, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, int count, Color color) {
    return GestureDetector(
      onTap: () => _showTaskListDialog(label, color),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 4),
            Icon(Icons.touch_app, size: 12, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, color: Colors.green),
                SizedBox(width: 8),
                Text('AI 분석 현황', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text('데이터 기간: ${_analytics!.totalDays}일'),
            Text('평균 완료율: ${(_analytics!.avgCompletionRate * 100).toStringAsFixed(1)}%'),
            if (!_analytics!.canRequestAnalysis)
              Text(
                'AI 상세 분석: ${_analytics!.daysUntilNextAnalysis}일 후 가능',
                style: const TextStyle(color: Colors.orange),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyAnalysisCard() {
    final weekly = _analytics!.weeklyAnalysis!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.purple),
                SizedBox(width: 8),
                Text('주간 분석', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text('완료: ${weekly.totalCompleted}개'),
            Text('시간 내 완료: ${weekly.totalOnTime}개 (${(weekly.onTimeRate * 100).toStringAsFixed(1)}%)'),
            Text('지연: ${weekly.totalOverdue}개'),
            
            if (weekly.insights.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('인사이트:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...weekly.insights.map((insight) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text('• $insight', style: const TextStyle(fontSize: 12)),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPartPerformanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pie_chart, color: Colors.orange),
                SizedBox(width: 8),
                Text('카테고리별 성과', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ..._analytics!.partPerformance.entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key),
                  Text('일평균 ${entry.value.toStringAsFixed(1)}개'),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestAdviceButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _analytics!.canRequestAnalysis ? _requestAIAdvice : null,
        icon: const Icon(Icons.psychology),
        label: Text(_analytics!.canRequestAnalysis 
          ? 'AI 맞춤 조언 받기' 
          : 'AI 조언 ${_analytics!.daysUntilNextAnalysis}일 후 가능'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Future<void> _requestAIAdvice() async {
    try {
      final advice = await widget.aiService.generatePersonalizedAdvice(_analytics!, widget.todos);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('🤖 AI 맞춤 조언'),
            content: SingleChildScrollView(
              child: Text(advice),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
        
        // 조언 요청 후 분석 상태 업데이트
        _loadAnalytics();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI 조언 요청 실패: $e')),
        );
      }
    }
  }

  void _showTaskListDialog(String label, Color color) {
    List<Todo> filteredTodos;
    String dialogTitle;
    IconData dialogIcon;

    switch (label) {
      case '활성':
        filteredTodos = widget.todos.where((t) => !t.done).toList();
        dialogTitle = '활성 할 일';
        dialogIcon = Icons.schedule;
        break;
      case '완료':
        filteredTodos = widget.todos.where((t) => t.done).toList();
        dialogTitle = '완료된 할 일';
        dialogIcon = Icons.check_circle;
        break;
      case '초과':
        filteredTodos = widget.todos.where((t) => t.isOverdue && !t.done).toList();
        dialogTitle = '기한 초과된 할 일';
        dialogIcon = Icons.warning;
        break;
      default:
        return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(dialogIcon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(dialogTitle),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: filteredTodos.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      '해당하는 할 일이 없습니다',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: filteredTodos.length,
                itemBuilder: (context, index) {
                  final todo = filteredTodos[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(todo.displayCategory),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  todo.displayCategory,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getPriorityColor(todo.priority),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  todo.priority.displayName,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            todo.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (todo.dueDate != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 12,
                                  color: todo.isOverdue ? Colors.red : Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${todo.dueDate!.month}/${todo.dueDate!.day}${todo.dueTime != null ? ' ${todo.dueTime!.format(context)}' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: todo.isOverdue ? Colors.red : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (todo.progressPercentage > 0 && todo.progressPercentage < 100) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: todo.progressPercentage / 100,
                                    backgroundColor: Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _getPriorityColor(todo.priority),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${todo.progressPercentage}%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case '학업':
        return Colors.blue;
      case '업무':
        return Colors.green;
      case '개인':
        return Colors.orange;
      case '건강':
        return Colors.red;
      case '취미':
        return Colors.purple;
      case '사회':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.urgent:
        return Colors.red[700]!;
      case Priority.high:
        return Colors.orange;
      case Priority.medium:
        return Colors.blue;
      case Priority.low:
        return Colors.grey;
    }
  }
}