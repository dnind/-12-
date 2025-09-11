import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// AI
import 'package:google_generative_ai/google_generative_ai.dart';

// Config
import 'config/api_keys.dart';

// ───────────────── Entry
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyAppRoot());
}

class MyAppRoot extends StatelessWidget {
  const MyAppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {
        '/': (_) => const AuthGate(),
        '/home': (_) => const HomePage(),
        '/login': (_) => const EmailLoginPage(),
        '/ai-advice': (_) => const AIAdvicePage(),
      },
      initialRoute: '/',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: false),
    );
  }
}

// ─────────────── AuthGate
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data != null) {
          return const HomePage();
        }
        return const EmailLoginPage();
      },
    );
  }
}

// ─────────────── Model
class Todo {
  final String id;
  String title;
  String part;
  DateTime? dueDate;
  bool done;

  Todo({
    required this.id,
    required this.title,
    required this.part,
    this.dueDate,
    this.done = false,
  });

  factory Todo.fromMap(Map<String, dynamic> m) => Todo(
    id: m['id'] as String,
    title: m['title'] as String,
    part: m['part'] as String? ?? '일반',
    dueDate: m['dueDate'] != null ? DateTime.tryParse(m['dueDate']) : null,
    done: m['done'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'part': part,
    'dueDate': dueDate?.toIso8601String(),
    'done': done,
  };
}

// ─────────────── AI Analysis Models
class DailyProgress {
  final String date; // YYYY-MM-DD 형식
  final int totalTodos;
  final int completedTodos;
  final Map<String, int> partProgress;
  final DateTime recordedAt;

  DailyProgress({
    required this.date,
    required this.totalTodos,
    required this.completedTodos,
    required this.partProgress,
    required this.recordedAt,
  });

  factory DailyProgress.fromFirestore(Map<String, dynamic> data) {
    return DailyProgress(
      date: data['date'] as String,
      totalTodos: data['totalTodos'] as int,
      completedTodos: data['completedTodos'] as int,
      partProgress: Map<String, int>.from(data['partProgress'] ?? {}),
      recordedAt: (data['recordedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'date': date,
    'totalTodos': totalTodos,
    'completedTodos': completedTodos,
    'partProgress': partProgress,
    'recordedAt': FieldValue.serverTimestamp(),
  };

  double get completionRate => totalTodos > 0 ? completedTodos / totalTodos : 0.0;
}

class CompletedTask {
  final String title;
  final String part;
  final DateTime completedAt;
  final DateTime? dueDate;
  final bool wasOverdue;

  CompletedTask({
    required this.title,
    required this.part,
    required this.completedAt,
    this.dueDate,
    required this.wasOverdue,
  });

  factory CompletedTask.fromFirestore(Map<String, dynamic> data) {
    final completedAt = (data['completedAt'] as Timestamp).toDate();
    final dueDate = data['dueDate'] != null 
        ? (data['dueDate'] as Timestamp).toDate() 
        : null;
    
    return CompletedTask(
      title: data['title'] as String,
      part: data['part'] as String,
      completedAt: completedAt,
      dueDate: dueDate,
      wasOverdue: dueDate != null && completedAt.isAfter(dueDate),
    );
  }
}

class UserAnalytics {
  final int totalDays;
  final int availableDays;
  final List<DailyProgress> dailyData;
  final double avgCompletionRate;
  final Map<String, double> partPerformance;
  final bool canRequestAnalysis;
  final DateTime? lastAnalysisDate;
  final int daysUntilNextAnalysis;

  UserAnalytics({
    required this.totalDays,
    required this.availableDays,
    required this.dailyData,
    required this.avgCompletionRate,
    required this.partPerformance,
    required this.canRequestAnalysis,
    this.lastAnalysisDate,
    required this.daysUntilNextAnalysis,
  });
}

// ─────────────── AI Service
class AIAnalysisService {
  late final GenerativeModel _model;

  AIAnalysisService() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: ApiKeys.geminiApiKey,
    );
  }

  // 하루 종료 시 일일 진행률을 Firestore에 저장
  Future<void> saveDailyProgress(String userId, List<Todo> todos) async {
    try {
      final now = DateTime.now();
      final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      final totalTodos = todos.length;
      final completedTodos = todos.where((t) => t.done).length;
      
      // 파트별 진행률 계산
      final partProgress = <String, int>{};
      for (final todo in todos.where((t) => t.done)) {
        partProgress[todo.part] = (partProgress[todo.part] ?? 0) + 1;
      }

      final dailyProgress = DailyProgress(
        date: dateKey,
        totalTodos: totalTodos,
        completedTodos: completedTodos,
        partProgress: partProgress,
        recordedAt: now,
      );

      // Firestore에 저장 (같은 날짜면 덮어쓰기)
      await FirebaseFirestore.instance
          .collection('daily_progress')
          .doc('${userId}_$dateKey')
          .set(dailyProgress.toFirestore());
    } catch (e) {
      print('일일 진행률 저장 실패: $e');
    }
  }

  Future<UserAnalytics> analyzeUserData(String userId) async {
    try {
      // 일일 진행률 데이터 조회 (userId로 필터링하기 위해 문서 ID 패턴 사용)
      final progressSnapshot = await FirebaseFirestore.instance
          .collection('daily_progress')
          .orderBy('recordedAt', descending: true)
          .get();

      // 클라이언트 측에서 userId 필터링
      final userDocs = progressSnapshot.docs.where((doc) => doc.id.startsWith('${userId}_')).toList();

      final dailyData = userDocs
          .map((doc) => DailyProgress.fromFirestore(doc.data()))
          .toList();

      // 마지막 AI 분석 시점 조회
      final lastAnalysisDoc = await FirebaseFirestore.instance
          .collection('ai_analysis_history')
          .doc(userId)
          .get();

      DateTime? lastAnalysisDate;
      if (lastAnalysisDoc.exists) {
        lastAnalysisDate = (lastAnalysisDoc.data()!['lastAnalysisDate'] as Timestamp).toDate();
      }

      // 분석 가능 여부 판단
      final canRequestAnalysis = _canRequestAnalysis(dailyData, lastAnalysisDate);
      final daysUntilNext = _calculateDaysUntilNext(dailyData, lastAnalysisDate);

      // 평균 완료율 계산
      final avgCompletionRate = dailyData.isEmpty 
          ? 0.0 
          : dailyData.map((d) => d.completionRate).reduce((a, b) => a + b) / dailyData.length;

      // 파트별 성과 계산
      final partPerformance = <String, double>{};
      if (dailyData.isNotEmpty) {
        final allParts = dailyData.expand((d) => d.partProgress.keys).toSet();
        for (final part in allParts) {
          final partDays = dailyData.where((d) => d.partProgress.containsKey(part)).toList();
          if (partDays.isNotEmpty) {
            final totalCompleted = partDays.map((d) => d.partProgress[part] ?? 0).reduce((a, b) => a + b);
            final avgPerDay = totalCompleted / partDays.length;
            partPerformance[part] = avgPerDay;
          }
        }
      }

      return UserAnalytics(
        totalDays: dailyData.length,
        availableDays: dailyData.length,
        dailyData: dailyData,
        avgCompletionRate: avgCompletionRate,
        partPerformance: partPerformance,
        canRequestAnalysis: canRequestAnalysis,
        lastAnalysisDate: lastAnalysisDate,
        daysUntilNextAnalysis: daysUntilNext,
      );
    } catch (e) {
      throw Exception('데이터 분석 실패: $e');
    }
  }

  bool _canRequestAnalysis(List<DailyProgress> dailyData, DateTime? lastAnalysisDate) {
    // 1. 최소 7일 데이터가 있어야 함
    if (dailyData.length < 7) return false;

    // 2. 마지막 분석이 없으면 가능
    if (lastAnalysisDate == null) return true;

    // 3. 마지막 분석 후 7일이 지났어야 함
    final daysSinceLastAnalysis = DateTime.now().difference(lastAnalysisDate).inDays;
    return daysSinceLastAnalysis >= 7;
  }

  int _calculateDaysUntilNext(List<DailyProgress> dailyData, DateTime? lastAnalysisDate) {
    if (dailyData.length < 7) {
      return 7 - dailyData.length;
    }

    if (lastAnalysisDate == null) return 0;

    final daysSinceLastAnalysis = DateTime.now().difference(lastAnalysisDate).inDays;
    return daysSinceLastAnalysis >= 7 ? 0 : 7 - daysSinceLastAnalysis;
  }

  Future<String> generatePersonalizedAdvice(UserAnalytics analytics, List<Todo> currentTodos) async {
    try {
      // AI 분석 요청 가능 여부 확인
      if (!analytics.canRequestAnalysis) {
        throw Exception('아직 AI 분석을 요청할 수 없습니다. ${analytics.daysUntilNextAnalysis}일 후에 다시 시도해주세요.');
      }

      final prompt = _buildAnalysisPrompt(analytics, currentTodos);
      
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      // 분석 완료 후 기록 저장
      await _saveAnalysisHistory(analytics.dailyData.first.date);
      
      return response.text ?? '조언을 생성할 수 없습니다.';
    } catch (e) {
      throw Exception('AI 조언 생성 실패: $e');
    }
  }

  Future<void> _saveAnalysisHistory(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('ai_analysis_history')
          .doc(userId)
          .set({
        'lastAnalysisDate': FieldValue.serverTimestamp(),
        'analysisCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      print('분석 기록 저장 실패: $e');
    }
  }

  String _buildAnalysisPrompt(UserAnalytics analytics, List<Todo> currentTodos) {
    final buffer = StringBuffer();
    buffer.writeln('당신은 개인 생산성 코치입니다. 다음 사용자의 ${analytics.totalDays}일간 데이터를 분석하여 개인화된 조언을 해주세요.');
    buffer.writeln('');
    buffer.writeln('【전체 성과 분석】');
    buffer.writeln('- 평균 완료율: ${(analytics.avgCompletionRate * 100).toStringAsFixed(1)}%');
    buffer.writeln('- 분석 기간: ${analytics.totalDays}일');
    buffer.writeln('');
    buffer.writeln('【파트별 평균 성과】');
    analytics.partPerformance.forEach((part, avg) {
      buffer.writeln('- $part: 일평균 ${avg.toStringAsFixed(1)}개 완료');
    });
    buffer.writeln('');
    buffer.writeln('【최근 일주일 트렌드】');
    final recentWeek = analytics.dailyData.take(7).toList();
    for (final day in recentWeek) {
      buffer.writeln('- ${day.date}: ${day.completedTodos}/${day.totalTodos} (${(day.completionRate * 100).toStringAsFixed(0)}%)');
    }
    buffer.writeln('');
    buffer.writeln('【현재 미완료 작업】');
    for (final todo in currentTodos.where((t) => !t.done)) {
      final dueText = todo.dueDate != null ? ' (마감: ${todo.dueDate!.month}/${todo.dueDate!.day})' : '';
      buffer.writeln('- [${todo.part}] ${todo.title}$dueText');
    }
    buffer.writeln('');
    buffer.writeln('이 데이터를 바탕으로 다음 항목에 대해 구체적이고 실용적인 조언을 250자 내외로 해주세요:');
    buffer.writeln('1. 패턴 분석 및 개선점');
    buffer.writeln('2. 강점 활용 방안'); 
    buffer.writeln('3. 다음 주 목표 및 전략');
    buffer.writeln('');
    buffer.writeln('친근하고 격려하는 톤으로 답변해 주세요.');

    return buffer.toString();
  }
}

// ─────────────── Home
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Todo> todos = [];
  bool _loading = true;
  final AIAnalysisService _aiService = AIAnalysisService();

  int get completedCount => todos.where((t) => t.done).length;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    // 앱 종료 시 일일 진행률 저장
    _saveDailyProgressIfNeeded();
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

  Future<void> _addTodo(String title, String part, DateTime? dueDate) async {
    final todo = Todo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      part: part,
      dueDate: dueDate,
    );
    setState(() => todos.add(todo));
    await _persist();
  }

  Future<void> _toggleDone(Todo t) async {
    final wasDone = t.done;
    setState(() => t.done = !t.done);
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
        'part': t.part,
        'dueDate': t.dueDate != null ? Timestamp.fromDate(t.dueDate!) : null,
        'completedAt': FieldValue.serverTimestamp(),
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
        onSubmit: (title, part, dueDate) async {
          if (title.trim().isNotEmpty) {
            await _addTodo(title, part, dueDate);
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
                case 'ai-advice':
                  Navigator.pushNamed(context, '/ai-advice');
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
                    // 로그인 화면으로 이동하고 이전 기록은 모두 삭제
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
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'ai-advice', child: Row(children: [
                Icon(Icons.psychology, size: 18),
                SizedBox(width: 8),
                Text('AI 조언'),
              ])),
              PopupMenuItem(value: 'settings', child: Text('설정')),
              PopupMenuItem(value: 'logout', child: Text('로그아웃')),
              PopupMenuItem(value: 'color', child: Text('컬러 선택')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '총 ${todos.length}개 · 완료 $completedCount개',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: '완료 항목 모두 삭제',
                  onPressed: () async {
                    final before = todos.length;
                    setState(() => todos.removeWhere((t) => t.done));
                    await _persist();
                    if (mounted && before != todos.length) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('완료 항목을 정리했어요.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.cleaning_services_outlined),
                ),
              ],
            ),
          ),
          Expanded(
            child: todos.isEmpty
                ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset('assets/cat.json', width: 220),
                const SizedBox(height: 12),
                const Text('할 일을 추가해볼까요?'),
              ],
            )
                : ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: todos.length,
              itemBuilder: (context, i) {
                final t = todos[i];
                return Dismissible(
                  key: ValueKey(t.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _deleteTodo(i),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: TodoTile(
                    index: i + 1,
                    todo: t,
                    onToggle: () => _toggleDone(t),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const FaIcon(FontAwesomeIcons.paw),
        label: const Text('추가하기'),
      ),
    );
  }
}

// ─────────────── Item
class TodoTile extends StatelessWidget {
  final int index;
  final Todo todo;
  final VoidCallback onToggle;

  const TodoTile({
    super.key,
    required this.index,
    required this.todo,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final due = todo.dueDate != null ? ' · 마감 ${_fmtDate(todo.dueDate!)}' : '';
    final titleStyle = TextStyle(
      fontSize: 16,
      decoration: todo.done ? TextDecoration.lineThrough : null,
      color: todo.done ? Colors.grey : null,
    );

    return ListTile(
      leading: Text('$index'),
      title: Text('${todo.title}  [${todo.part}]$due', style: titleStyle),
      trailing: IconButton(
        tooltip: todo.done ? '미완료로 표시' : '완료로 표시',
        onPressed: onToggle,
        icon: Icon(todo.done ? Icons.check_circle : Icons.radio_button_unchecked),
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ─────────────── Add Dialog
class AddTodoDialog extends StatefulWidget {
  final Future<void> Function(String title, String part, DateTime? dueDate)
  onSubmit;

  const AddTodoDialog({super.key, required this.onSubmit});

  @override
  State<AddTodoDialog> createState() => _AddTodoDialogState();
}

class _AddTodoDialogState extends State<AddTodoDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedPart = '일반';
  DateTime? _dueDate;

  final _parts = const ['일반', '개발', '디자인', '기획', '운영'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      await widget.onSubmit(_controller.text, _selectedPart, _dueDate);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pets, size: 48, color: Colors.pinkAccent),
            const SizedBox(height: 20),
            const Text('할 일 추가', style: TextStyle(fontSize: 22)),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: '예) 고양이 모래 갈기',
                      border: OutlineInputBorder(),
                      labelText: '제목',
                    ),
                    textInputAction: TextInputAction.done,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return '내용을 입력해주세요';
                      if (v.trim().length > 100) return '100자 이내로 입력해주세요';
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedPart,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: '파트',
                    ),
                    items: _parts
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedPart = v!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: '마감일(선택)',
                          ),
                          child: Text(
                            _dueDate == null
                                ? '선택 안 함'
                                : '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _pickDate,
                        child: const Text('날짜 선택'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _submit, child: const Text('추가')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────── Email Login
class EmailLoginPage extends StatefulWidget {
  const EmailLoginPage({super.key});
  @override
  State<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pw.text.trim(),
      );
      // AuthGate가 알아서 홈으로 전환
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'user-not-found' => '등록되지 않은 이메일이에요.',
        'wrong-password' => '비밀번호가 틀렸습니다.',
        'invalid-email' => '이메일 형식을 확인해주세요.',
        'too-many-requests' => '잠시 후 다시 시도해주세요.',
        _ => '로그인 실패: ${e.message}',
      };
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pw.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입 성공! 로그인해주세요.')),
      );
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = '이미 등록된 이메일입니다. 로그인 버튼을 눌러주세요.';
          break;
        case 'invalid-email':
          msg = '이메일 형식이 올바르지 않습니다.';
          break;
        case 'weak-password':
          msg = '비밀번호는 6자 이상이어야 합니다.';
          break;
        case 'operation-not-allowed':
          msg = '이메일/비밀번호 로그인이 비활성화되어 있습니다(콘솔에서 켜주세요).';
          break;
        case 'network-request-failed':
          msg = '네트워크 연결을 확인해주세요.';
          break;
        case 'too-many-requests':
          msg = '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.';
          break;
        default:
          msg = '회원가입 실패: ${e.code}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('이메일 로그인')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _email,
              decoration: const InputDecoration(
                labelText: '이메일',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pw,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '비밀번호',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : Column(
              children: [
                ElevatedButton(onPressed: _signIn, child: const Text('로그인')),
                TextButton(onPressed: _signUp, child: const Text('회원가입')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────── Settings / Color
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: const Center(child: Text('설정(자리만)')),
    );
  }
}

class ColorPickerPage extends StatelessWidget {
  const ColorPickerPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('컬러 선택')),
      body: const Center(child: Text('컬러 선택(자리만)')),
    );
  }
}

// ─────────────── AI Advice Page
class AIAdvicePage extends StatefulWidget {
  const AIAdvicePage({super.key});
  @override
  State<AIAdvicePage> createState() => _AIAdvicePageState();
}

class _AIAdvicePageState extends State<AIAdvicePage> {
  final AIAnalysisService _aiService = AIAnalysisService();
  UserAnalytics? _analytics;
  String? _advice;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAIAdvice();
  }

  Future<void> _loadAIAdvice() async {
    if (_loading) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // 현재 사용자의 로컬 할 일 목록 불러오기
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('todos');
      List<Todo> currentTodos = [];
      if (raw != null) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        currentTodos = list.map(Todo.fromMap).toList();
      }

      // 사용자 데이터 분석
      final analytics = await _aiService.analyzeUserData(user.uid);
      
      // AI 조언 생성
      final advice = await _aiService.generatePersonalizedAdvice(analytics, currentTodos);

      setState(() {
        _analytics = analytics;
        _advice = advice;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.dongle(
      color: Colors.black,
      fontSize: 32,
      fontWeight: FontWeight.bold,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('AI 조언', style: titleStyle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAIAdvice,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('AI가 분석 중입니다...', style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          '오류가 발생했습니다',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _loadAIAdvice,
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 분석 결과 섹션
                      if (_analytics != null) ...[
                        _buildAnalyticsCard(_analytics!),
                        const SizedBox(height: 20),
                      ],
                      
                      // AI 조언 요청 버튼
                      if (_analytics != null) ...[
                        _buildAnalysisRequestCard(_analytics!),
                        const SizedBox(height: 20),
                      ],
                      
                      // AI 조언 섹션
                      if (_advice != null) _buildAdviceCard(_advice!),
                      
                      // 빈 상태
                      if (_analytics == null)
                        const Center(
                          child: Column(
                            children: [
                              Icon(Icons.psychology_outlined, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('아직 분석할 데이터가 부족합니다.', style: TextStyle(fontSize: 16)),
                              Text('할 일을 완료하고 다시 확인해보세요!', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildAnalyticsCard(UserAnalytics analytics) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.blue),
                const SizedBox(width: 8),
                Text('${analytics.totalDays}일간 데이터 분석', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            
            // AI 분석 상태
            _buildAnalysisStatusCard(analytics),
            const SizedBox(height: 16),
            
            // 전체 통계
            Row(
              children: [
                Expanded(
                  child: _buildStatItem('누적 일수', '${analytics.totalDays}일', Colors.blue),
                ),
                Expanded(
                  child: _buildStatItem('평균 완료율', '${(analytics.avgCompletionRate * 100).toStringAsFixed(0)}%', Colors.green),
                ),
                Expanded(
                  child: _buildStatItem('다음 분석', analytics.canRequestAnalysis ? '가능' : '${analytics.daysUntilNextAnalysis}일 후', 
                      analytics.canRequestAnalysis ? Colors.green : Colors.orange),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 파트별 성과
            if (analytics.partPerformance.isNotEmpty) ...[
              const Text('파트별 평균 성과', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: analytics.partPerformance.entries.map((entry) {
                  return Chip(
                    label: Text('${entry.key} ${entry.value.toStringAsFixed(1)}/일'),
                    backgroundColor: Colors.blue.withOpacity(0.1),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisStatusCard(UserAnalytics analytics) {
    final statusColor = analytics.canRequestAnalysis ? Colors.green : Colors.orange;
    final statusIcon = analytics.canRequestAnalysis ? Icons.check_circle : Icons.schedule;
    
    String statusText;
    String detailText;
    
    if (analytics.totalDays < 7) {
      statusText = 'AI 분석 준비 중';
      detailText = '${7 - analytics.totalDays}일 더 사용하시면 AI 분석을 요청할 수 있어요!';
    } else if (analytics.canRequestAnalysis) {
      statusText = 'AI 분석 가능';
      detailText = '지금 AI 조언을 요청할 수 있습니다.';
    } else {
      statusText = 'AI 분석 대기 중';
      detailText = '마지막 분석 후 ${analytics.daysUntilNextAnalysis}일 후에 다시 요청할 수 있어요.';
      if (analytics.lastAnalysisDate != null) {
        final lastDate = analytics.lastAnalysisDate!;
        detailText += ' (마지막: ${lastDate.month}/${lastDate.day})';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statusText, style: TextStyle(fontWeight: FontWeight.w600, color: statusColor)),
                Text(detailText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildAnalysisRequestCard(UserAnalytics analytics) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.purple),
                const SizedBox(width: 8),
                const Text('AI 조언 요청', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            
            if (analytics.canRequestAnalysis) ...[
              const Text('준비완료! AI가 당신의 패턴을 분석하여 개인화된 조언을 제공할 수 있어요.'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _requestAIAdvice,
                  icon: const Icon(Icons.psychology),
                  label: const Text('AI 조언 받기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ] else ...[
              Text(
                analytics.totalDays < 7
                    ? '${7 - analytics.totalDays}일 더 사용하시면 AI 분석을 요청할 수 있어요!'
                    : '마지막 분석 후 ${analytics.daysUntilNextAnalysis}일 후에 다시 요청할 수 있어요.',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.psychology),
                  label: Text(analytics.totalDays < 7 ? '데이터 수집 중...' : '대기 중...'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _requestAIAdvice() async {
    if (_analytics == null || !_analytics!.canRequestAnalysis) return;

    setState(() {
      _loading = true;
      _error = null;
      _advice = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // 현재 사용자의 로컬 할 일 목록 불러오기
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('todos');
      List<Todo> currentTodos = [];
      if (raw != null) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        currentTodos = list.map(Todo.fromMap).toList();
      }

      // AI 조언 생성
      final advice = await _aiService.generatePersonalizedAdvice(_analytics!, currentTodos);

      setState(() {
        _advice = advice;
        // 분석 완료 후 analytics 새로고침
        _loadAIAdvice();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _buildAdviceCard(String advice) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: Colors.purple),
                const SizedBox(width: 8),
                const Text('AI의 개인화된 조언', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.withOpacity(0.2)),
              ),
              child: Text(
                advice,
                style: const TextStyle(fontSize: 16, height: 1.6),
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text('AI가 당신의 패턴을 분석해 맞춤 조언을 제공했어요', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
