import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macha/screens/calender_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/todo_model.dart';
import '../managers/progress_manager.dart';
import '../managers/notification_manager.dart';
import '../services/ai_analysis_service.dart';
import '../utils/timezone_utils.dart';
import '../widgets/add_todo_dialog.dart';
import '../widgets/todo_tile.dart';
import '../widgets/ai_insights_tab.dart';
import '../services/admin_service.dart';
import 'settings_page.dart';
import 'color_picker_page.dart';
import 'admin_dashboard.dart';
import 'diary_main_page.dart';
import 'diary_editor_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  List<Todo> todos = [];
  bool _loading = true;
  final AIAnalysisService _aiService = AIAnalysisService();
  late TabController _tabController;

  DateTime? _filterDate; // 선택한 날짜

  // Todo 변경 알림을 위한 ValueNotifier
  final ValueNotifier<int> _todosChangedNotifier = ValueNotifier<int>(0);

  int get completedCount => todos.where((t) => t.done).length;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // FAB 업데이트를 위한 리스너
    });
    _restore();
    _initializeAdminIfNeeded();
  }
  
  Future<void> _initializeAdminIfNeeded() async {
    if (AdminService.isAdmin()) {
      await AdminService.initializeAdminRole();
    }
  }

  @override
  void dispose() {
    _saveDailyProgressIfNeeded();
    _tabController.dispose();
    _todosChangedNotifier.dispose();
    super.dispose();
  }

  Future<void> _saveDailyProgressIfNeeded() async {
    const user = 'local_user';
    if (todos.isNotEmpty) {
      await _aiService.saveDailyProgress(user, todos);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = todos.map((t) => t.toMap()).toList();
    await prefs.setString('todos', jsonEncode(jsonList));

    // Todo 변경 알림 - 캘린더에 즉시 반영
    _todosChangedNotifier.value++;
    print('홈: Todo 변경 알림 발송 (${_todosChangedNotifier.value})');
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('todos');
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      todos = list.map(Todo.fromMap).toList();
    }
    setState(() => _loading = false);
  }

  Future<void> _addTodo(
      String title,
      String category,
      String? customCategory,
      DateTime? dueDate,
      TimeOfDay? dueTime,
      DueDateType dueDateType,
      Priority priority,
      NotificationInterval notificationInterval,
      ) async {
    final todo = Todo(
      id: TimeZoneUtils.kstNow.millisecondsSinceEpoch.toString(),
      title: title.trim(),
      part: category,
      category: category,
      customCategory: customCategory,
      dueDate: dueDate,
      dueTime: dueTime,
      dueDateType: dueDateType,
      priority: priority,
      notificationInterval: notificationInterval,
      nextNotificationTime: notificationInterval != NotificationInterval.none
          ? NotificationManager.calculateNextNotification(
        TimeZoneUtils.kstNow,
        notificationInterval,
      )
          : null,
    );
    setState(() => todos.add(todo));
    await _persist();
  }

  Future<void> _toggleDone(Todo t) async {
    final wasDone = t.done;
    setState(() {
      t.done = !t.done;
      if (t.done) {
        t.progressPercentage = 100;
      } else {
        t.progressPercentage = 0;
      }
      if (t.parentId != null) {
        ProgressManager.updateParentProgress(t.parentId!, todos);
      }
    });

    await _persist();

    if (!wasDone && t.done) {
      await _saveCompletionToFirestore(t);
    }
  }

  Future<void> _saveCompletionToFirestore(Todo t) async {
    try {
      // 로컬 저장소에 완료 기록 저장
      final prefs = await SharedPreferences.getInstance();

      // 기존 완료 기록 목록 가져오기
      final completedTasksString = prefs.getString('completed_tasks') ?? '[]';
      final List<dynamic> completedTasksList = jsonDecode(completedTasksString);

      // 새로운 완료 기록 추가
      final completionRecord = {
        'userId': 'local_user',
        'todoId': t.id,
        'title': t.title,
        'category': t.category,
        'customCategory': t.customCategory,
        'part': t.part, // 기존 호환성
        'priority': t.priority.index,
        'priorityName': t.priority.displayName,
        'progressPercentage': t.progressPercentage,
        'isSubtask': t.isSubtask,
        'parentId': t.parentId,
        'subtaskCount': t.subtaskIds.length,
        'dueDate': t.dueDate?.toIso8601String(),
        'dueTime': t.dueTime != null ? {
          'hour': t.dueTime!.hour,
          'minute': t.dueTime!.minute,
        } : null,
        'dueDateType': t.dueDateType.index,
        'dueDateTypeName': t.dueDateType.displayName,
        'notificationInterval': t.notificationInterval.index,
        'notificationIntervalName': t.notificationInterval.displayName,
        'wasOverdue': t.isOverdue,
        'wasDueSoon': t.isDueSoon,
        'completedAt': DateTime.now().toIso8601String(),
        'completedAtKST': TimeZoneUtils.kstNow.toIso8601String(),
      };

      completedTasksList.add(completionRecord);

      // 완료 기록 목록 저장
      await prefs.setString('completed_tasks', jsonEncode(completedTasksList));

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('완료 기록을 저장했어요.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로컬 저장 실패: $e')),
        );
      }
    }
  }

  Future<void> _deleteTodo(int index, {bool showUndo = true}) async {
    final removed = todos[index];
    setState(() => todos.removeAt(index));
    await _persist();

    if (showUndo && mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('삭제했어요. 되돌릴까요?'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              setState(() => todos.insert(index, removed));
              await _persist();
            },
          ),
        ),
      );
    }
  }

  void _handleAddButtonPress() {
    switch (_tabController.index) {
      case 0: // Todo 탭
        _openAddDialog();
        break;
      case 1: // AI 인사이트 탭
        // AI 인사이트 탭에서는 + 버튼 비활성화하거나 다른 동작
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI 인사이트 탭에서는 새로운 항목을 추가할 수 없습니다.')),
        );
        break;
      case 2: // 다이어리 탭
        _openDiaryEditor();
        break;
    }
  }

  void _openAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AddTodoDialog(
        onSubmit: (
            title,
            category,
            customCategory,
            dueDate,
            dueTime,
            dueDateType,
            priority,
            notificationInterval,
            ) async {
          if (title.trim().isNotEmpty) {
            await _addTodo(
              title,
              category,
              customCategory,
              dueDate,
              dueTime,
              dueDateType,
              priority,
              notificationInterval,
            );
          }
        },
      ),
    );
  }

  void _openDiaryEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DiaryEditorPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.dongle(
      color: Colors.black,
      fontSize: 50,
      fontWeight: FontWeight.bold,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('해라냥', style: titleStyle),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'admin':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminDashboard()),
                  );
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                  break;
                case 'logout':
                  // 로컬 모드에서는 로그인 화면으로 이동
                  if (context.mounted) {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                  break;
                case 'color':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ColorPickerPage()),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              // 관리자 메뉴 (관리자만 표시)
              if (AdminService.isAdmin())
                const PopupMenuItem(
                  value: 'admin',
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('관리자 대시보드', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              const PopupMenuItem(value: 'settings', child: Text('설정')),
              const PopupMenuItem(value: 'logout', child: Text('로그아웃')),
              const PopupMenuItem(value: 'color', child: Text('컬러 선택')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.checklist), text: 'Todo'),
            Tab(icon: Icon(Icons.analytics), text: 'AI 인사이트'),
            Tab(icon: Icon(Icons.book), text: '나만의 다이어리'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodoTab(),
          AIInsightsTab(aiService: _aiService, todos: todos),
          const DiaryMainPage(),
        ],
      ),
      floatingActionButton: _tabController.index == 2
          ? null // 다이어리 탭에서는 FAB 숨김 (다이어리 페이지가 자체 FAB 보유)
          : Stack(
              children: [
                // 기존 + 버튼 (왼쪽 아래로 살짝 이동)
                Positioned(
                  bottom: 16,
                  right: 80,
                  child: FloatingActionButton(
                    heroTag: "addButton",
                    onPressed: _handleAddButtonPress,
                    backgroundColor: Colors.indigo.shade400,
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),

                // ✅ 새 캘린더 버튼 (오른쪽 아래)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: "calendarButton",
                    backgroundColor: Colors.pinkAccent.shade200,
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true, // 위로 쭉 올라오게
                        backgroundColor: Colors.transparent, // 둥근 효과
                        builder: (context) => FractionallySizedBox(
                          heightFactor: 0.95, // 거의 전체 화면
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(25),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: CalendarPage(
                              onDateSelected: (selectedDate) {
                                setState(() {
                                  _filterDate = selectedDate;
                                });
                              },
                              todosChangedNotifier: _todosChangedNotifier,
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Icon(Icons.calendar_month, color: Colors.white),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTodoTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredTodos = _filterDate == null
        ? todos
        : todos.where((t) =>
    t.dueDate != null &&
        t.dueDate!.year == _filterDate!.year &&
        t.dueDate!.month == _filterDate!.month &&
        t.dueDate!.day == _filterDate!.day,
    ).toList();

    if (filteredTodos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.task_alt, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              _filterDate == null
                  ? '할 일이 없어요!'
                  : '${_filterDate!.month}월 ${_filterDate!.day}일 일정이 없어요!',
              style: GoogleFonts.dongle(fontSize: 30, color: Colors.grey),
            ),
            if (_filterDate != null)
              TextButton(
                onPressed: () => setState(() => _filterDate = null),
                child: const Text('모든 일정 보기'),
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade50, Colors.indigo.shade50],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.task, color: Colors.indigo.shade600, size: 24),
              const SizedBox(width: 8),
              Text(
                '진행 현황',
                style: GoogleFonts.dongle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${filteredTodos.where((t) => t.done).length} / ${filteredTodos.length}',
                  style: GoogleFonts.dongle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filteredTodos.length,
            itemBuilder: (context, index) {
              final todo = filteredTodos[index];
              return TodoTile(
                todo: todo,
                onToggle: () => _toggleDone(todo),
                onDelete: () => _deleteTodo(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

