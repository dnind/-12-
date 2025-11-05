import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../services/ai_diary_service.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, Map<String, dynamic>> decorations = {}; // stickers + color + style

  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadAllDecorations();
  }

  Future<void> _loadAllDecorations() async {
    if (currentUser == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('calendar_decorations')
        .where("userId", isEqualTo: currentUser!.uid)
        .get();

    final Map<DateTime, Map<String, dynamic>> loaded = {};
    for (var doc in snap.docs) {
      final date = DateTime.parse(doc["date"]);
      loaded[DateTime(date.year, date.month, date.day)] = {
        "stickers": List<String>.from(doc["stickers"]),
        "color": doc["color"],
        "style": doc["style"]
      };
    }

    setState(() => decorations = loaded);
  }

  Future<void> _saveDecoration(DateTime date, Map<String, dynamic> data) async {
    if (currentUser == null) return;
    final normalized = DateTime(date.year, date.month, date.day);
    final docId = "${currentUser!.uid}_${normalized.toIso8601String().split("T")[0]}";

    await FirebaseFirestore.instance
        .collection('calendar_decorations')
        .doc(docId)
        .set({
      "userId": currentUser!.uid,
      "date": "${normalized.year}-${normalized.month.toString().padLeft(2,'0')}-${normalized.day.toString().padLeft(2,'0')}",
      "stickers": data["stickers"],
      "color": data["color"],
      "style": data["style"],
    });
  }

  /// AI 추천 호출
  Future<Map<String, dynamic>?> _fetchAiRecommendation({
    required String title,
    required String description,
    required DateTime date,
    String? location,
  }) async {
    final prompt = AiPromptService.buildPrompt(
      title: title,
      description: description,
      date: date,
      location: location,
    );

    final resp = await http.post(
      Uri.parse('https://your-server.com/api/recommend'), // 백엔드 엔드포인트
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"prompt": prompt}),
    );

    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      return body['recommendation'] as Map<String, dynamic>?;
    }
    return null;
  }

  /// 일정 생성 + AI 추천
  Future<void> _addTodoWithRecommendation(String title, String description, DateTime date) async {
    final rec = await _fetchAiRecommendation(title: title, description: description, date: date);
    if (rec != null) {
      setState(() {
        final normalized = DateTime(date.year, date.month, date.day);
        decorations[normalized] = rec;
      });
      await _saveDecoration(date, rec);
    }
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
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      final normalized = DateTime(day.year, day.month, day.day);
                      final data = decorations[normalized];
                      if (data != null && data["stickers"] != null) {
                        return Positioned(
                          bottom: 4,
                          child: Text(
                            (data["stickers"] as List<String>).join(" "),
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    // 예시: 일정 제목/설명 직접 입력
                    await _addTodoWithRecommendation(
                      "카페 글쓰기",
                      "커피 마시며 글쓰기 2시간",
                      _selectedDay ?? DateTime.now(),
                    );
                  },
                  child: const Text("AI 추천 적용"),
                ),
                const SizedBox(height: 16),
                if (_selectedDay != null)
                  Column(
                    children: [
                      Text(
                        "선택한 날짜: ${_selectedDay!.year}-${_selectedDay!.month}-${_selectedDay!.day}",
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      if (decorations[DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)] != null)
                        Wrap(
                          children: (decorations[DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)]!["stickers"] as List<String>)
                              .map((s) => Text(s, style: const TextStyle(fontSize: 30)))
                              .toList(),
                        )
                      else
                        const Text("아직 AI 추천이 없습니다 😸"),
                    ],
                  )
              ],
            ),
          ),
        );
      },
    );
  }
}
