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

// ─────────────── Home
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Todo> todos = [];
  bool _loading = true;

  int get completedCount => todos.where((t) => t.done).length;

  @override
  void initState() {
    super.initState();
    _restore();
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
