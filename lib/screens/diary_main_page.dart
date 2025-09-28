import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diary_models.dart';
import '../services/diary_service.dart';
import 'diary_editor_page.dart';
import 'quiz_bank_page.dart';

class DiaryMainPage extends StatefulWidget {
  const DiaryMainPage({Key? key}) : super(key: key);

  @override
  _DiaryMainPageState createState() => _DiaryMainPageState();
}

class _DiaryMainPageState extends State<DiaryMainPage> {
  final DiaryService _diaryService = DiaryService();
  DiaryCategory? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryFilter(),
          Expanded(
            child: _buildDiaryList(),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'quiz_bank',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QuizBankPage()),
              );
            },
            backgroundColor: Colors.indigo,
            child: const Icon(Icons.quiz, color: Colors.white),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'add_diary',
            onPressed: () => _navigateToEditor(null),
            backgroundColor: Colors.deepPurple,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '일기 검색...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildCategoryChip(null, '전체'),
          ...DiaryCategory.values.map((category) =>
              _buildCategoryChip(category, category.korean)),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(DiaryCategory? category, String label) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? category : null;
          });
        },
        backgroundColor: Colors.white,
        selectedColor: Colors.deepPurple.withOpacity(0.2),
        labelStyle: TextStyle(
          color: isSelected ? Colors.deepPurple : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  Widget _buildDiaryList() {
    return FutureBuilder<List<DiaryEntry>>(
      future: _loadDiaries(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('오류: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('다이어리가 없습니다.'));
        }
        return _buildDiaryGrid(snapshot.data!);
      },
    );
  }

  Future<List<DiaryEntry>> _loadDiaries() async {
    if (_searchQuery.isNotEmpty) {
      return await _diaryService.searchDiaries(_searchQuery);
    } else if (_selectedCategory != null) {
      return await _diaryService.getDiariesByCategory(_selectedCategory!);
    } else {
      return await _diaryService.getUserDiaries();
    }
  }

  Widget _buildDiaryGrid(List<DiaryEntry> diaries) {
    if (diaries.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: diaries.length,
      itemBuilder: (context, index) {
        return _buildDiaryCard(diaries[index]);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_outlined,
            size: 100,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 20),
          Text(
            '아직 작성한 일기가 없어요',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '오늘의 이야기를 기록해보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => _navigateToEditor(null),
            icon: const Icon(Icons.add),
            label: const Text('첫 일기 작성하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
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

  Widget _buildDiaryCard(DiaryEntry diary) {
    final decoration = diary.decoration != null
        ? DiaryDecoration.fromJson(diary.decoration!)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: decoration != null
            ? BorderSide(
                color: Color(int.parse(decoration.textColor.replaceAll('#', '0xFF'))),
                width: decoration.borderStyle == 'dashed' ? 2 : 1,
                style: decoration.borderStyle == 'dashed'
                    ? BorderStyle.none
                    : BorderStyle.solid,
              )
            : BorderSide.none,
      ),
      color: decoration != null
          ? Color(int.parse(decoration.backgroundColor.replaceAll('#', '0xFF')))
          : Colors.white,
      child: InkWell(
        onTap: () => _navigateToEditor(diary),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCategoryBadge(diary.category),
                  Text(
                    DateFormat('yyyy.MM.dd').format(diary.date),
                    style: TextStyle(
                      color: decoration != null
                          ? Color(int.parse(decoration.textColor.replaceAll('#', '0xFF'))).withOpacity(0.7)
                          : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                diary.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: decoration != null
                      ? Color(int.parse(decoration.textColor.replaceAll('#', '0xFF')))
                      : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                diary.content,
                style: TextStyle(
                  fontSize: 14,
                  color: decoration != null
                      ? Color(int.parse(decoration.textColor.replaceAll('#', '0xFF'))).withOpacity(0.8)
                      : Colors.grey.shade700,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (diary.stickers.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: diary.stickers.take(5).map((sticker) {
                    return Text(
                      sticker,
                      style: const TextStyle(fontSize: 20),
                    );
                  }).toList(),
                ),
              ],
              if (diary.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: diary.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.deepPurple,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(DiaryCategory category) {
    Color bgColor;
    Color textColor;

    switch (category) {
      case DiaryCategory.study:
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade700;
        break;
      case DiaryCategory.travel:
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade700;
        break;
      case DiaryCategory.daily:
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        category.korean,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  void _navigateToEditor(DiaryEntry? diary) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiaryEditorPage(diary: diary),
      ),
    );
  }
}