import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarPage extends StatefulWidget {
  final Function(DateTime)? onDateSelected; // ✅ 날짜 선택 콜백

  const CalendarPage({super.key, this.onDateSelected});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<String>> _todosByDate = {};

  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadAllTodos();
  }

  /// ✅ Firestore에서 사용자 일정 불러오기
  Future<void> _loadAllTodos() async {
    if (currentUser == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('todos')
        .where("userId", isEqualTo: currentUser!.uid)
        .get();

    final Map<DateTime, List<String>> loaded = {};
    for (var doc in snap.docs) {
      final date = DateTime.parse(doc["date"]);
      final normalized = DateTime(date.year, date.month, date.day);
      loaded.putIfAbsent(normalized, () => []);
      loaded[normalized]!.add(doc["title"]);
    }

    setState(() => _todosByDate = loaded);
  }

  /// ✅ 날짜 클릭 시 일정 목록 표시
  void _showDaySchedule(DateTime selectedDay) {
    final normalized = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final tasks = _todosByDate[normalized] ?? [];

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
            if (tasks.isEmpty)
              const Text("이 날에는 일정이 없습니다."),
            if (tasks.isNotEmpty)
              ...tasks.map((t) => ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(t),
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
