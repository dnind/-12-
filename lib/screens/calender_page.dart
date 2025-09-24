import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  /// 날짜별 스티커/메모 저장소
  Map<DateTime, List<String>> decorations = {};

  /// 스티커 리스트 (100개 이상)
  final List<String> stickerList = [
    "😀","😁","😂","🤣","😅","😊","😍","😘","😎","🤩",
    "🥳","😴","😡","😭","😇","🤔","🙄","😏","😌","😜",
    "🐶","🐱","🐭","🐹","🐰","🦊","🐻","🐼","🐨","🐯",
    "🦁","🐮","🐷","🐸","🐵","🐧","🐦","🐤","🦆","🦉",
    "🌸","🌼","🌻","🌹","🥀","🌷","🌺","🌲","🌴","🌵",
    "🍎","🍌","🍉","🍇","🍓","🍒","🍑","🥝","🍍","🥭",
    "🍔","🍟","🍕","🌭","🍿","🥗","🍣","🍩","🍪","🍫",
    "⭐","🌟","✨","🔥","💧","🌈","❄️","☀️","🌙","☁️",
    "❤️","🧡","💛","💚","💙","💜","🖤","🤍","💖","💝",
    "🎵","🎶","🎤","🎧","🎹","🥁","🎸","🎺","🎻","🎷",
  ];

  /// 스티커 고르는 다이얼로그
  Future<String?> _pickSticker(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("스티커 선택"),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6, // 한 줄에 6개
                childAspectRatio: 1,
              ),
              itemCount: stickerList.length,
              itemBuilder: (context, index) {
                final sticker = stickerList[index];
                return InkWell(
                  onTap: () => Navigator.pop(context, sticker),
                  child: Center(
                    child: Text(sticker, style: const TextStyle(fontSize: 24)),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// 날짜에 꾸미기 추가
  void _addDecoration(DateTime date) async {
    final sticker = await _pickSticker(context);
    if (sticker != null) {
      setState(() {
        final normalized = DateTime(date.year, date.month, date.day);
        decorations[normalized] = [
          ...(decorations[normalized] ?? []),
          sticker
        ];
      });
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Icon(Icons.drag_handle, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text("📅 달력", style: Theme.of(context).textTheme.headlineSmall),
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
                    _addDecoration(selectedDay); // 날짜 선택 시 꾸미기 추가
                  },
                  calendarFormat: CalendarFormat.month,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      final normalized = DateTime(day.year, day.month, day.day);
                      final stickers = decorations[normalized];
                      if (stickers != null && stickers.isNotEmpty) {
                        return Positioned(
                          bottom: 4,
                          child: Text(
                            stickers.join(" "),
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),
                if (_selectedDay != null) ...[
                  Text(
                    "선택한 날짜: ${_selectedDay!.year}-${_selectedDay!.month}-${_selectedDay!.day}",
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  if (decorations[DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)] != null)
                    Wrap(
                      children: decorations[DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)]!
                          .map((sticker) => Text(sticker, style: const TextStyle(fontSize: 30)))
                          .toList(),
                    )
                  else
                    const Text("아직 꾸민 게 없어요 😸"),
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}
