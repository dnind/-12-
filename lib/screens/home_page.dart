import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  int get completedCount => todos.where((t) => t.done).length;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    // 앱 종료 시 일일 진행률 저장
    _saveDailyProgressIfNeeded();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _saveDailyProgressIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && todos.isNotEmpty) {
      await _aiService.saveDailyProgress(user.uid, todos);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = todos.map((t) => t.toMap()).toList();
    await prefs.setString('todos', jsonEncode(jsonList));
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

  Future<void> _addTodo(String title, String category, String? customCategory, DateTime? dueDate, TimeOfDay? dueTime, DueDateType dueDateType, Priority priority, NotificationInterval notificationInterval) async {
    final todo = Todo(
      id: TimeZoneUtils.kstNow.millisecondsSinceEpoch.toString(),
      title: title.trim(),
      part: category,  // 기존 호환성
      category: category,
      customCategory: customCategory,
      dueDate: dueDate,
      dueTime: dueTime,
      dueDateType: dueDateType,
      priority: priority,
      notificationInterval: notificationInterval,
      nextNotificationTime: notificationInterval != NotificationInterval.none 
        ? NotificationManager.calculateNextNotification(TimeZoneUtils.kstNow, notificationInterval)
        : null,
    );
    setState(() => todos.add(todo));
    await _persist();
  }

  Future<void> _toggleDone(Todo t) async {
    final wasDone = t.done;
    setState(() {
      t.done = !t.done;
      
      // 진행률 업데이트
      if (t.done) {
        t.progressPercentage = 100;
      } else {
        t.progressPercentage = 0;
      }
      
      // 부모 태스크 진행률 업데이트
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
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? 'anonymous';

      await FirebaseFirestore.instance.collection('completed_tasks').add({
        'userId': uid,
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
        'dueDate': t.dueDate != null ? Timestamp.fromDate(t.dueDate!) : null,
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
        'completedAt': FieldValue.serverTimestamp(),
        'completedAtKST': Timestamp.fromDate(TimeZoneUtils.kstNow),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('완료 기록을 저장했어요.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Firestore 저장 실패: $e')),
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

  void _openAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AddTodoDialog(
        onSubmit: (title, category, customCategory, dueDate, dueTime, dueDateType, priority, notificationInterval) async {
          if (title.trim().isNotEmpty) {
            await _addTodo(title, category, customCategory, dueDate, dueTime, dueDateType, priority, notificationInterval);
          }
        },
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
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
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
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTodoTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (todos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.task_alt, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              '할 일이 없어요!',
              style: GoogleFonts.dongle(fontSize: 30, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              '새로운 할 일을 추가해보세요',
              style: GoogleFonts.dongle(fontSize: 20, color: Colors.grey),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$completedCount / ${todos.length}',
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
            itemCount: todos.length,
            itemBuilder: (context, index) {
              final todo = todos[index];
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