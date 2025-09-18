import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class MyDiaryApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diary App',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: DiaryHomePage(),
    );
  }
}

class DiaryHomePage extends StatefulWidget {
  @override
  _DiaryHomePageState createState() => _DiaryHomePageState();
}

class _DiaryHomePageState extends State<DiaryHomePage> {
  final List<String> todoList = ["아침 운동하기", "회의 준비", "일기 쓰기"];

  void _openCalendar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 전체 화면에 가깝게 열기 가능
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: DateTime.now(),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Colors.indigo,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("오늘의 할 일"),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: _openCalendar,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: todoList.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: Icon(Icons.check_box_outline_blank),
            title: Text(todoList[index]),
          );
        },
      ),
    );
  }
}
