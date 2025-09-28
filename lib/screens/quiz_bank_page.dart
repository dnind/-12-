import 'package:flutter/material.dart';
import '../models/diary_models.dart';
import '../services/diary_service.dart';

class QuizBankPage extends StatefulWidget {
  const QuizBankPage({Key? key}) : super(key: key);

  @override
  _QuizBankPageState createState() => _QuizBankPageState();
}

class _QuizBankPageState extends State<QuizBankPage> {
  final DiaryService _diaryService = DiaryService();
  List<QuizQuestion> _allQuizzes = [];
  List<QuizQuestion> _currentQuizzes = [];
  int _currentQuestionIndex = 0;
  int? _selectedAnswer;
  bool _showAnswer = false;
  int _correctAnswers = 0;
  int _totalAnswered = 0;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }

  Future<void> _loadQuizzes() async {
    setState(() => _isLoading = true);

    try {
      print('=== 문제은행 로딩 시작 ===');

      // 모든 다이어리를 가져와서 공부 카테고리만 필터링
      final allDiaries = await _diaryService.getUserDiaries().first;
      print('전체 다이어리 개수: ${allDiaries.length}');

      final studyDiaries = allDiaries.where((diary) => diary.category == DiaryCategory.study).toList();
      print('공부 다이어리 개수: ${studyDiaries.length}');

      List<QuizQuestion> allQuizzes = [];

      for (final diary in studyDiaries) {
        print('다이어리 처리 중: ${diary.title}');
        print('AI 분석 존재: ${diary.aiAnalysis != null}');

        if (diary.aiAnalysis != null) {
          print('AI 분석 데이터: ${diary.aiAnalysis}');
          print('카테고리별 분석 존재: ${diary.aiAnalysis!.containsKey('categorySpecific')}');

          if (diary.aiAnalysis!['categorySpecific'] != null) {
            try {
              final categoryData = diary.aiAnalysis!['categorySpecific'];
              print('카테고리 데이터 타입: ${categoryData.runtimeType}');
              print('카테고리 데이터: $categoryData');

              final studyAnalysis = StudyAnalysis.fromJson(
                categoryData as Map<String, dynamic>
              );

              print('퀴즈 문제 개수: ${studyAnalysis.quizQuestions.length}');

            // 각 퀴즈에 출처 다이어리 정보 추가
            for (final quiz in studyAnalysis.quizQuestions) {
              allQuizzes.add(QuizQuestion(
                question: '[${diary.title}] ${quiz.question}',
                options: quiz.options,
                correctAnswerIndex: quiz.correctAnswerIndex,
                explanation: quiz.explanation,
              ));
            }
          } catch (e) {
            print('StudyAnalysis 파싱 오류: $e');
          }
        }
      }

      print('총 로드된 퀴즈 개수: ${allQuizzes.length}');

      setState(() {
        _allQuizzes = allQuizzes;
        _currentQuizzes = List.from(allQuizzes);
        _isLoading = false;
      });
    } catch (e) {
      print('문제은행 로딩 오류: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('문제를 불러오는 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _filterQuizzes(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _currentQuizzes = List.from(_allQuizzes);
      } else {
        _currentQuizzes = _allQuizzes
            .where((quiz) =>
                quiz.question.toLowerCase().contains(query.toLowerCase()) ||
                quiz.explanation.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
      _currentQuestionIndex = 0;
      _resetQuizState();
    });
  }

  void _selectAnswer(int answerIndex) {
    if (_showAnswer) return;

    setState(() {
      _selectedAnswer = answerIndex;
    });
  }

  void _showAnswerAndExplanation() {
    if (_selectedAnswer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('답을 선택해주세요')),
      );
      return;
    }

    setState(() {
      _showAnswer = true;
      _totalAnswered++;
      if (_selectedAnswer == _currentQuizzes[_currentQuestionIndex].correctAnswerIndex) {
        _correctAnswers++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _currentQuizzes.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _resetQuizState();
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        _resetQuizState();
      });
    }
  }

  void _resetQuizState() {
    setState(() {
      _selectedAnswer = null;
      _showAnswer = false;
    });
  }

  void _resetAllProgress() {
    setState(() {
      _correctAnswers = 0;
      _totalAnswered = 0;
      _currentQuestionIndex = 0;
      _resetQuizState();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📚 학습 문제은행'),
        backgroundColor: Colors.blue.shade50,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetAllProgress,
            tooltip: '진행상황 초기화',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildQuizContent(),
    );
  }

  Widget _buildQuizContent() {
    if (_allQuizzes.isEmpty) {
      return _buildEmptyState();
    }

    if (_currentQuizzes.isEmpty) {
      return _buildNoResultsState();
    }

    return Column(
      children: [
        _buildSearchBar(),
        _buildProgressIndicator(),
        Expanded(child: _buildQuizCard()),
        _buildNavigationButtons(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.quiz_outlined,
            size: 100,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 20),
          Text(
            '아직 생성된 문제가 없어요',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '공부 다이어리를 작성하고 AI 분석을 받아보세요!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.book),
            label: const Text('다이어리 작성하러 가기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '검색 결과가 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '"$_searchQuery"와 관련된 문제를 찾을 수 없어요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: '문제 내용으로 검색...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _filterQuizzes(''),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
        onChanged: _filterQuizzes,
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '문제 ${_currentQuestionIndex + 1} / ${_currentQuizzes.length}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (_totalAnswered > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '정답률: ${(_correctAnswers / _totalAnswered * 100).toInt()}% ($_correctAnswers/$_totalAnswered)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuizCard() {
    final quiz = _currentQuizzes[_currentQuestionIndex];

    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '문제',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                quiz.question,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ...quiz.options.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                final isSelected = _selectedAnswer == index;
                final isCorrect = index == quiz.correctAnswerIndex;

                Color backgroundColor = Colors.grey.shade50;
                Color borderColor = Colors.grey.shade300;
                Color textColor = Colors.black87;

                if (_showAnswer) {
                  if (isCorrect) {
                    backgroundColor = Colors.green.shade50;
                    borderColor = Colors.green;
                    textColor = Colors.green.shade700;
                  } else if (isSelected && !isCorrect) {
                    backgroundColor = Colors.red.shade50;
                    borderColor = Colors.red;
                    textColor = Colors.red.shade700;
                  }
                } else if (isSelected) {
                  backgroundColor = Colors.blue.shade50;
                  borderColor = Colors.blue;
                  textColor = Colors.blue.shade700;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _selectAnswer(index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        border: Border.all(color: borderColor, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: borderColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                String.fromCharCode(65 + index), // A, B, C, D
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: isSelected || (_showAnswer && isCorrect)
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (_showAnswer && isCorrect)
                            const Icon(Icons.check_circle, color: Colors.green),
                          if (_showAnswer && isSelected && !isCorrect)
                            const Icon(Icons.cancel, color: Colors.red),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              if (_showAnswer) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.amber.shade700),
                          const SizedBox(width: 8),
                          Text(
                            '해설',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        quiz.explanation,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (!_showAnswer) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _showAnswerAndExplanation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '정답 확인',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _currentQuestionIndex > 0 ? _previousQuestion : null,
              icon: const Icon(Icons.arrow_back),
              label: const Text('이전 문제'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                foregroundColor: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _currentQuestionIndex < _currentQuizzes.length - 1
                  ? _nextQuestion
                  : null,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('다음 문제'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}