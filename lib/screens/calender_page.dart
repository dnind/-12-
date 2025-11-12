import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/todo_model.dart';

class CalendarPage extends StatefulWidget {
  final Function(DateTime)? onDateSelected; // ✅ 날짜 선택 콜백
  final ValueNotifier<int>? todosChangedNotifier; // ✅ Todo 변경 알림

  const CalendarPage({super.key, this.onDateSelected, this.todosChangedNotifier});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Todo>> _todosByDate = {};

  @override
  void initState() {
    super.initState();
    _loadAllTodos();

    // Todo 변경 감지 리스너 등록
    widget.todosChangedNotifier?.addListener(_onTodosChanged);
  }

  @override
  void dispose() {
    // 리스너 제거
    widget.todosChangedNotifier?.removeListener(_onTodosChanged);
    super.dispose();
  }

  void _onTodosChanged() {
    print('캘린더: Todo 변경 감지 - 자동 새로고침');
    _loadAllTodos();
  }

  /// ✅ SharedPreferences에서 사용자 일정 불러오기
  Future<void> _loadAllTodos() async {
    print('=== 캘린더: Todo 로딩 시작 ===');
    final prefs = await SharedPreferences.getInstance();
    final String? todosJson = prefs.getString('todos');

    if (todosJson == null) {
      print('캘린더: 저장된 Todo 없음');
      setState(() => _todosByDate = {});
      return;
    }

    final List<dynamic> todosList = json.decode(todosJson);
    final List<Todo> todos = todosList.map((m) => Todo.fromMap(m as Map<String, dynamic>)).toList();

    print('캘린더: 로드된 Todo 개수: ${todos.length}');

    final Map<DateTime, List<Todo>> loaded = {};
    for (var todo in todos) {
      if (todo.dueDate != null) {
        final date = todo.dueDate!;
        final normalized = DateTime(date.year, date.month, date.day);
        loaded.putIfAbsent(normalized, () => []);
        loaded[normalized]!.add(todo);
        print('캘린더: ${date.year}년 ${date.month}월 ${date.day}일 (정규화: ${normalized.toString().substring(0, 10)}) - ${todo.title}');
      } else {
        print('캘린더: 마감일 없음 - ${todo.title}');
      }
    }

    print('캘린더: 날짜별 Todo 개수: ${loaded.length}');
    setState(() => _todosByDate = loaded);
  }

  /// ✅ 외부에서 호출할 수 있는 새로고침 메서드
  void refresh() {
    print('캘린더: 새로고침 요청됨');
    _loadAllTodos();
  }

  /// ✅ 날짜 클릭 시 일정 목록 표시
  void _showDaySchedule(DateTime selectedDay) {
    final normalized = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final todos = _todosByDate[normalized] ?? [];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${selectedDay.year}년 ${selectedDay.month}월 ${selectedDay.day}일 일정",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (todos.isEmpty)
              const Text("이 날에는 일정이 없습니다."),
            if (todos.isNotEmpty)
              ...todos.map((todo) => ListTile(
                leading: Icon(
                  todo.done ? Icons.check_circle : Icons.check_circle_outline,
                  color: todo.done ? Colors.green : todo.priority.color,
                ),
                title: Text(
                  todo.title,
                  style: TextStyle(
                    decoration: todo.done ? TextDecoration.lineThrough : null,
                    color: todo.done ? Colors.grey : null,
                  ),
                ),
                subtitle: Text(
                  '${todo.displayCategory} - ${todo.dueDateDisplay}',
                  style: TextStyle(
                    fontSize: 12,
                    color: todo.isOverdue ? Colors.red : Colors.grey,
                  ),
                ),
              )),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                widget.onDateSelected?.call(selectedDay); // ✅ 홈으로 전달
                Navigator.pop(context); // 모달 닫기
                Navigator.pop(context); // 캘린더 닫기
              },
              child: const Text("이 날짜로 보기"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: [
                const Center(child: Icon(Icons.drag_handle, color: Colors.grey)),
                const SizedBox(height: 16),
                TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    _showDaySchedule(selectedDay); // ✅ 일정 모달 표시
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      final normalized = DateTime(day.year, day.month, day.day);
                      final hasTodo = _todosByDate.containsKey(normalized);

                      // 9월 12일 체크 (2024년과 2025년 모두)
                      if (day.month == 9 && day.day == 12) {
                        print('캘린더 마커: ${day.year}년 9월 12일 체크 - Todo 있음: $hasTodo');
                        if (hasTodo) {
                          print('캘린더 마커: 해당 날짜의 Todo 개수: ${_todosByDate[normalized]!.length}');
                        }
                      }

                      if (hasTodo) {
                        return Positioned(
                          bottom: 4,
                          child: Icon(Icons.star, size: 10, color: Colors.pinkAccent),
                        );
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
