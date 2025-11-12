import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diary_models.dart';
import '../services/diary_service.dart';
import 'quiz_bank_page.dart';

class DiaryEditorPage extends StatefulWidget {
  final DiaryEntry? diary;

  const DiaryEditorPage({Key? key, this.diary}) : super(key: key);

  @override
  _DiaryEditorPageState createState() => _DiaryEditorPageState();
}

class _DiaryEditorPageState extends State<DiaryEditorPage> {
  final DiaryService _diaryService = DiaryService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  DiaryCategory? _selectedCategory; // null로 시작 (선택 안 됨)
  DiaryTheme? _selectedTheme;
  DateTime _selectedDate = DateTime.now();
  List<String> _selectedStickers = [];
  List<String> _tags = [];
  DiaryAIAnalysis? _aiAnalysis;
  DiaryDecoration? _decoration;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  final int _minContentLength = 50;

  // 원본 데이터 저장 (변경 감지용)
  String _originalTitle = '';
  String _originalContent = '';
  String _originalLocation = '';
  DiaryCategory? _originalCategory;
  DateTime? _originalDate;
  List<String> _originalTags = [];
  List<String> _originalStickers = [];
  DiaryDecoration? _originalDecoration;

  @override
  void initState() {
    super.initState();
    if (widget.diary != null) {
      _loadDiaryData(widget.diary!);
    }
  }

  void _loadDiaryData(DiaryEntry diary) {
    _titleController.text = diary.title;
    _contentController.text = diary.content;
    _locationController.text = diary.location ?? '';
    _selectedCategory = diary.category;
    _selectedTheme = diary.theme;
    _selectedDate = diary.date;
    _selectedStickers = List.from(diary.stickers);
    _tags = List.from(diary.tags);

    // 원본 데이터 저장
    _originalTitle = diary.title;
    _originalContent = diary.content;
    _originalLocation = diary.location ?? '';
    _originalCategory = diary.category;
    _originalDate = diary.date;
    _originalTags = List.from(diary.tags);
    _originalStickers = List.from(diary.stickers);

    if (diary.aiAnalysis != null) {
      _aiAnalysis = DiaryAIAnalysis.fromJson(diary.aiAnalysis!);
    }
    if (diary.decoration != null) {
      _decoration = DiaryDecoration.fromJson(diary.decoration!);
      _originalDecoration = DiaryDecoration.fromJson(diary.decoration!);
    }
  }

  // 변경사항이 있는지 확인
  bool get _hasChanges {
    if (widget.diary == null) return true; // 새 다이어리는 항상 저장 가능

    // Decoration 변경 체크
    bool decorationChanged = false;
    if (_decoration != null && _originalDecoration != null) {
      decorationChanged = _decoration!.backgroundColor != _originalDecoration!.backgroundColor ||
          _decoration!.textColor != _originalDecoration!.textColor ||
          _decoration!.borderStyle != _originalDecoration!.borderStyle;
    } else if (_decoration != _originalDecoration) {
      decorationChanged = true;
    }

    return _titleController.text != _originalTitle ||
        _contentController.text != _originalContent ||
        _locationController.text != _originalLocation ||
        _selectedCategory != _originalCategory ||
        _selectedDate != _originalDate ||
        !_listEquals(_tags, _originalTags) ||
        !_listEquals(_selectedStickers, _originalStickers) ||
        decorationChanged;
  }

  // 리스트 비교 헬퍼 함수
  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _locationController.dispose();
    // DiaryService는 싱글톤이므로 dispose하지 않음
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.diary == null ? '새 일기 작성' : '일기 수정',
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          if (widget.diary != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _deleteDiary,
            ),
          TextButton(
            onPressed: (_isSaving || !_hasChanges) ? null : _saveDiary,
            child: Text(
              '저장',
              style: TextStyle(
                color: (_isSaving || !_hasChanges) ? Colors.grey : Colors.deepPurple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _decoration != null ? _buildDecoratedView() : _buildNormalView(),
      floatingActionButton: _buildFloatingButtons(),
    );
  }

  Widget _buildNormalView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateSelector(),
          const SizedBox(height: 16),
          _buildCategorySelector(),
          const SizedBox(height: 16),
          _buildTitleField(),
          const SizedBox(height: 16),
          _buildContentField(),
          const SizedBox(height: 16),
          _buildLocationField(),
          const SizedBox(height: 16),
          _buildTagsSection(),
          if (_selectedStickers.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildStickersSection(),
          ],
          if (_aiAnalysis != null) ...[
            const SizedBox(height: 24),
            _buildAIAnalysisSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildDecoratedView() {
    final bgColor = Color(int.parse(_decoration!.backgroundColor.replaceAll('#', '0xFF')));
    final textColor = Color(int.parse(_decoration!.textColor.replaceAll('#', '0xFF')));

    return Container(
      color: bgColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateSelector(textColor: textColor),
            const SizedBox(height: 16),
            _buildCategorySelector(),
            const SizedBox(height: 16),
            _buildTitleField(textColor: textColor),
            const SizedBox(height: 16),
            _buildContentField(textColor: textColor),
            const SizedBox(height: 16),
            _buildLocationField(textColor: textColor),
            const SizedBox(height: 16),
            _buildTagsSection(),
            if (_selectedStickers.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildStickersSection(),
            ],
            if (_aiAnalysis != null) ...[
              const SizedBox(height: 24),
              _buildAIAnalysisSection(textColor: textColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector({Color? textColor}) {
    return InkWell(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 20, color: textColor ?? Colors.grey.shade600),
            const SizedBox(width: 12),
            Text(
              DateFormat('yyyy년 MM월 dd일').format(_selectedDate),
              style: TextStyle(
                fontSize: 16,
                color: textColor ?? Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: DiaryCategory.values.map((category) {
          final isSelected = _selectedCategory == category;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = category),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.deepPurple : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  category.korean,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTitleField({Color? textColor}) {
    return TextField(
      controller: _titleController,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: textColor ?? Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: '제목을 입력하세요',
        hintStyle: TextStyle(color: (textColor ?? Colors.grey).withOpacity(0.5)),
        border: InputBorder.none,
        filled: true,
        fillColor: Colors.white.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
        ),
      ),
      onChanged: (value) => setState(() {}), // 변경 감지를 위한 setState
    );
  }

  Widget _buildContentField({Color? textColor}) {
    return TextField(
      controller: _contentController,
      maxLines: 10,
      style: TextStyle(
        fontSize: 16,
        height: 1.5,
        color: textColor ?? Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: '오늘의 이야기를 적어보세요...\n\n(최소 $_minContentLength자 이상 입력하시면 AI가 분석해드려요)',
        hintStyle: TextStyle(color: (textColor ?? Colors.grey).withOpacity(0.5)),
        border: InputBorder.none,
        filled: true,
        fillColor: Colors.white.withOpacity(0.5),
        contentPadding: const EdgeInsets.all(16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
        ),
      ),
      onChanged: (value) {
        setState(() {});
      },
    );
  }

  Widget _buildLocationField({Color? textColor}) {
    return TextField(
      controller: _locationController,
      style: TextStyle(color: textColor ?? Colors.black87),
      onChanged: (value) => setState(() {}), // 변경 감지를 위한 setState
      decoration: InputDecoration(
        hintText: '위치 (선택사항)',
        hintStyle: TextStyle(color: (textColor ?? Colors.grey).withOpacity(0.5)),
        prefixIcon: const Icon(Icons.location_on_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.5),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '태그',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._tags.map((tag) => Chip(
                  label: Text(tag),
                  onDeleted: () => setState(() => _tags.remove(tag)),
                  backgroundColor: Colors.deepPurple.withOpacity(0.1),
                )),
            ActionChip(
              label: const Icon(Icons.add, size: 16),
              onPressed: _addTag,
              backgroundColor: Colors.grey.shade200,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStickersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '스티커',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _selectedStickers.map((sticker) {
            return GestureDetector(
              onTap: () => setState(() => _selectedStickers.remove(sticker)),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(sticker, style: const TextStyle(fontSize: 24)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAIAnalysisSection({Color? textColor}) {
    if (_aiAnalysis == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.withOpacity(0.1),
            Colors.blue.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Text(
                'AI 분석 결과',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor ?? Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAnalysisItem('요약', _aiAnalysis!.summary, textColor: textColor),
          if (_aiAnalysis!.advice != null)
            _buildAnalysisItem('조언', _aiAnalysis!.advice!, textColor: textColor),
          if (_selectedCategory == DiaryCategory.study && _aiAnalysis!.categorySpecific != null) ...[
            _buildStudyAnalysis(StudyAnalysis.fromJson(_aiAnalysis!.categorySpecific!), textColor: textColor),
            const SizedBox(height: 16),
            _buildQuizBankButton(),
          ],
          if (_selectedCategory == DiaryCategory.travel && _aiAnalysis!.categorySpecific != null)
            _buildTravelAnalysis(TravelAnalysis.fromJson(_aiAnalysis!.categorySpecific!), textColor: textColor),
        ],
      ),
    );
  }

  Widget _buildAnalysisItem(String title, String content, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: (textColor ?? Colors.deepPurple).withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: textColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyAnalysis(StudyAnalysis analysis, {Color? textColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analysis.keyPoints.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '핵심 포인트',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: (textColor ?? Colors.deepPurple).withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          ...analysis.keyPoints.map((point) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Text(
                        point,
                        style: TextStyle(fontSize: 14, color: textColor ?? Colors.black87),
                      ),
                    ),
                  ],
                ),
              )),
        ],
        if (analysis.quizQuestions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '복습 퀴즈',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: (textColor ?? Colors.deepPurple).withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          ...analysis.quizQuestions.map((quiz) => _buildQuizCard(quiz, textColor: textColor)),
        ],
      ],
    );
  }

  Widget _buildQuizCard(QuizQuestion quiz, {Color? textColor}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quiz.question,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...quiz.options.asMap().entries.map((entry) {
              final isCorrect = entry.key == quiz.correctAnswerIndex;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle : Icons.circle_outlined,
                      size: 16,
                      color: isCorrect ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(entry.value, style: TextStyle(fontSize: 12))),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTravelAnalysis(TravelAnalysis analysis, {Color? textColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analysis.placesmentioned.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '언급된 장소',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: (textColor ?? Colors.deepPurple).withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: analysis.placesmentioned.map((place) => Chip(
              label: Text(place, style: const TextStyle(fontSize: 12)),
              backgroundColor: Colors.green.withOpacity(0.1),
            )).toList(),
          ),
        ],
        if (analysis.recommendations.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '추천 장소',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: (textColor ?? Colors.deepPurple).withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          ...analysis.recommendations.map((rec) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rec,
                        style: TextStyle(fontSize: 14, color: textColor ?? Colors.black87),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildQuizBankButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const QuizBankPage()),
          );
        },
        icon: const Icon(Icons.quiz, color: Colors.white),
        label: const Text(
          '📚 문제은행에서 복습하기',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildFloatingButtons() {
    // 새 다이어리 작성 중일 때는 AI 분석 버튼 숨김
    final isNewDiary = widget.diary == null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (!isNewDiary && _aiAnalysis == null) ...[
          FloatingActionButton(
            heroTag: 'analyze',
            onPressed: _isAnalyzing ? null : _analyzeDiary,
            backgroundColor: Colors.deepPurple,
            child: _isAnalyzing
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.auto_awesome, color: Colors.white),
          ),
          const SizedBox(height: 8),
        ],
        if (_aiAnalysis != null && _decoration == null) ...[
          FloatingActionButton(
            heroTag: 'decorate',
            onPressed: _applyDecoration,
            backgroundColor: Colors.pink,
            child: const Icon(Icons.palette, color: Colors.white),
          ),
          const SizedBox(height: 8),
        ],
        if (_decoration != null) ...[
          FloatingActionButton(
            heroTag: 'reset',
            onPressed: () => setState(() => _decoration = null),
            backgroundColor: Colors.grey,
            child: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ],
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _addTag() {
    showDialog(
      context: context,
      builder: (context) {
        String newTag = '';
        return AlertDialog(
          title: const Text('태그 추가'),
          content: TextField(
            onChanged: (value) => newTag = value,
            decoration: const InputDecoration(hintText: '태그 입력'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                if (newTag.isNotEmpty && !_tags.contains(newTag)) {
                  setState(() => _tags.add(newTag));
                }
                Navigator.pop(context);
              },
              child: const Text('추가'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _analyzeDiary() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카테고리를 먼저 선택해주세요 (공부/여행/일상)')),
      );
      return;
    }

    if (_contentController.text.length < _minContentLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('최소 $_minContentLength자 이상 입력해주세요')),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final analysis = await _diaryService.analyzeDiary(
        _contentController.text,
        _selectedCategory!,
      );

      print('=== setState 호출 전 ===');
      print('분석 결과 요약: ${analysis.summary}');
      print('제안된 태그 개수: ${analysis.suggestedTags.length}');
      print('제안된 스티커 개수: ${analysis.suggestedStickers.length}');

      setState(() {
        _aiAnalysis = analysis;
        if (analysis.suggestedTags.isNotEmpty) {
          _tags = [..._tags, ...analysis.suggestedTags.where((tag) => !_tags.contains(tag))];
        }
        if (analysis.suggestedStickers.isNotEmpty) {
          _selectedStickers = [..._selectedStickers, ...analysis.suggestedStickers];
        }
        _selectedTheme = analysis.suggestedTheme;
      });

      print('=== setState 호출 후 ===');
      print('_aiAnalysis null 여부: ${_aiAnalysis == null}');
      print('태그 개수: ${_tags.length}');
      print('스티커 개수: ${_selectedStickers.length}');
      print('테마: $_selectedTheme');

      // AI 분석 후 자동 저장 (기존 다이어리인 경우만)
      if (widget.diary != null) {
        print('기존 일기 - 자동 저장 시도');
        await _saveDiary();
        print('자동 저장 완료');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI 분석이 완료되고 저장되었습니다!')),
          );
        }
      } else {
        print('새 일기 - 저장하지 않음');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI 분석 완료! 저장 버튼을 눌러 저장하세요.')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('분석 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _applyDecoration() async {
    if (_selectedTheme == null) return;

    final decoration = await _diaryService.generateDecoration(
      _selectedTheme!,
      _selectedStickers,
    );

    setState(() => _decoration = decoration);
  }

  Future<void> _saveDiary() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 내용을 입력해주세요')),
      );
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카테고리를 선택해주세요 (공부/여행/일상)')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final diary = DiaryEntry(
        id: widget.diary?.id ?? '',
        userId: '',
        title: _titleController.text,
        content: _contentController.text,
        date: _selectedDate,
        category: _selectedCategory!,
        theme: _selectedTheme,
        stickers: _selectedStickers,
        aiAnalysis: _aiAnalysis?.toJson(),
        decoration: _decoration?.toJson(),
        location: _locationController.text.isEmpty ? null : _locationController.text,
        tags: _tags,
        createdAt: widget.diary?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.diary == null) {
        await _diaryService.createDiary(diary);
      } else {
        await _diaryService.updateDiary(diary);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteDiary() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일기 삭제'),
        content: const Text('정말 이 일기를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _diaryService.deleteDiary(widget.diary!.id);
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }
}