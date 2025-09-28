import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/admin_service.dart';
import '../services/ai_analysis_service.dart';
import '../models/todo_model.dart';
import '../managers/notification_manager.dart';
import '../utils/timezone_utils.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> 
    with TickerProviderStateMixin {
  late TabController _tabController;
  SystemStats? _systemStats;
  List<UserData>? _users;
  bool _loading = true;
  String? _error;
  
  // 테스트용 알림 설정
  final _testTodoController = TextEditingController();
  NotificationInterval _testNotificationInterval = NotificationInterval.hourly;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAdminData();
    _initializeAdminRole();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _testTodoController.dispose();
    super.dispose();
  }
  
  Future<void> _initializeAdminRole() async {
    await AdminService.initializeAdminRole();
  }
  
  Future<void> _loadAdminData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final stats = await AdminService.getSystemStats();
      final users = await AdminService.getAllUsers();
      
      setState(() {
        _systemStats = stats;
        _users = users;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (!AdminService.isAdmin()) {
      return Scaffold(
        appBar: AppBar(title: const Text('접근 거부')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.security, size: 80, color: Colors.red),
              SizedBox(height: 20),
              Text(
                '관리자 권한이 필요합니다',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text('super@root.com 계정으로 로그인해주세요.'),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              '관리자 대시보드',
              style: GoogleFonts.dongle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade50,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAdminData,
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'logout':
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                  break;
                case 'system_notice':
                  _showSystemNoticeDialog();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'system_notice',
                child: Row(
                  children: [
                    Icon(Icons.announcement, size: 16),
                    SizedBox(width: 8),
                    Text('시스템 공지'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 16),
                    SizedBox(width: 8),
                    Text('로그아웃'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: '대시보드'),
            Tab(icon: Icon(Icons.people), text: '사용자 관리'),
            Tab(icon: Icon(Icons.analytics), text: '분석 리포트'),
            Tab(icon: Icon(Icons.notifications), text: '알림 테스트'),
            Tab(icon: Icon(Icons.settings), text: '시스템 설정'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildUsersTab(),
          _buildAnalyticsTab(),
          _buildNotificationTestTab(),
          _buildSystemSettingsTab(),
        ],
      ),
    );
  }
  
  Widget _buildDashboardTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('오류 발생: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAdminData,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 시스템 상태 요약
          Row(
            children: [
              const Icon(Icons.dashboard, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                '시스템 현황',
                style: GoogleFonts.dongle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_systemStats != null) ...[
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '전체 사용자',
                    _systemStats!.totalUsers.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '오늘 활성 사용자',
                    _systemStats!.activeToday.toString(),
                    Icons.person_outline,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '전체 할 일',
                    _systemStats!.totalTodos.toString(),
                    Icons.task,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '완료율',
                    '${(_systemStats!.completionRate * 100).toStringAsFixed(1)}%',
                    Icons.check_circle,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'AI 분석 횟수',
                    _systemStats!.totalAIAnalysis.toString(),
                    Icons.psychology,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '현재 시간 (KST)',
                    TimeZoneUtils.kstNow.toString().substring(0, 19),
                    Icons.access_time,
                    Colors.teal,
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 32),
          
          // 빠른 액션
          Row(
            children: [
              const Icon(Icons.flash_on, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                '빠른 액션',
                style: GoogleFonts.dongle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildActionButton(
                '시스템 공지',
                Icons.announcement,
                Colors.blue,
                _showSystemNoticeDialog,
              ),
              _buildActionButton(
                '사용자 분석',
                Icons.analytics,
                Colors.green,
                () => _tabController.animateTo(2),
              ),
              _buildActionButton(
                '알림 테스트',
                Icons.notifications_active,
                Colors.orange,
                () => _tabController.animateTo(3),
              ),
              _buildActionButton(
                'AI 강제 분석',
                Icons.psychology,
                Colors.purple,
                _forceAIAnalysis,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
  
  Widget _buildUsersTab() {
    if (_users == null) return const Center(child: CircularProgressIndicator());
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '총 ${_users!.length}명의 사용자',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _loadAdminData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('새로고침'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _users!.length,
            itemBuilder: (context, index) {
              final user = _users![index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: user.role == 'admin' ? Colors.red : Colors.blue,
                    child: Icon(
                      user.role == 'admin' ? Icons.admin_panel_settings : Icons.person,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(user.displayName ?? user.email),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${user.email} (${user.role})'),
                      if (user.lastLogin != null)
                        Text(
                          '마지막 로그인: ${user.lastLogin!.toString().substring(0, 19)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (user.role != 'admin')
                        IconButton(
                          icon: const Icon(Icons.admin_panel_settings),
                          tooltip: '관리자로 승격',
                          onPressed: () => _changeUserRole(user.userId, 'admin'),
                        ),
                      IconButton(
                        icon: const Icon(Icons.info),
                        tooltip: '상세 정보',
                        onPressed: () => _showUserDetail(user.userId),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 시스템 분석 리포트',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          if (_systemStats != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '전체 사용자 활동 통계',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildAnalyticsRow('총 사용자', '${_systemStats!.totalUsers}명'),
                    _buildAnalyticsRow('오늘 활성 사용자', '${_systemStats!.activeToday}명'),
                    _buildAnalyticsRow('활성 비율', '${(_systemStats!.activeToday / _systemStats!.totalUsers * 100).toStringAsFixed(1)}%'),
                    const Divider(),
                    _buildAnalyticsRow('전체 할 일', '${_systemStats!.totalTodos}개'),
                    _buildAnalyticsRow('완료된 할 일', '${_systemStats!.completedTodos}개'),
                    _buildAnalyticsRow('전체 완료율', '${(_systemStats!.completionRate * 100).toStringAsFixed(1)}%'),
                    const Divider(),
                    _buildAnalyticsRow('AI 분석 총 횟수', '${_systemStats!.totalAIAnalysis}회'),
                    _buildAnalyticsRow('사용자당 평균 분석', '${(_systemStats!.totalAIAnalysis / _systemStats!.totalUsers).toStringAsFixed(1)}회'),
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '시스템 상태 모니터링',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildAnalyticsRow('현재 시간 (KST)', TimeZoneUtils.kstNow.toString().substring(0, 19)),
                  _buildAnalyticsRow('서버 상태', '정상 운영'),
                  _buildAnalyticsRow('데이터베이스', 'Firebase Firestore'),
                  _buildAnalyticsRow('AI 서비스', 'Google Gemini 1.5 Flash'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnalyticsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  Widget _buildNotificationTestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔔 알림 시스템 테스트',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '테스트 할 일 생성',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _testTodoController,
                    decoration: const InputDecoration(
                      labelText: '테스트 할 일 제목',
                      hintText: '예: 알림 테스트 작업',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<NotificationInterval>(
                    value: _testNotificationInterval,
                    decoration: const InputDecoration(
                      labelText: '알림 간격',
                      border: OutlineInputBorder(),
                    ),
                    items: NotificationInterval.values
                        .where((interval) => interval != NotificationInterval.none)
                        .map((interval) => DropdownMenuItem(
                          value: interval,
                          child: Text(interval.displayName),
                        ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _testNotificationInterval = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _createTestTodo,
                          icon: const Icon(Icons.add_task),
                          label: const Text('테스트 할 일 생성'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _testNotificationCalculation,
                          icon: const Icon(Icons.calculate),
                          label: const Text('알림 시간 계산'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '알림 간격별 테스트 정보',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...NotificationInterval.values
                      .where((interval) => interval != NotificationInterval.none)
                      .map((interval) => _buildNotificationInfo(interval)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNotificationInfo(NotificationInterval interval) {
    final nextTime = NotificationManager.calculateNextNotification(
      TimeZoneUtils.kstNow, 
      interval
    );
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              interval.displayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              nextTime != null 
                  ? nextTime.toString().substring(0, 19)
                  : '계산 불가',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSystemSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚙️ 시스템 설정',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '관리자 정보',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildSettingRow('관리자 이메일', AdminService.adminEmail),
                  _buildSettingRow('현재 사용자', FirebaseAuth.instance.currentUser?.email ?? 'Unknown'),
                  _buildSettingRow('권한 상태', AdminService.isAdmin() ? '관리자' : '일반 사용자'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '시스템 관리',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loadAdminData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('전체 데이터 새로고침'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showSystemNoticeDialog,
                      icon: const Icon(Icons.announcement),
                      label: const Text('시스템 공지사항 발송'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _forceAIAnalysis,
                      icon: const Icon(Icons.psychology),
                      label: const Text('AI 분석 강제 실행'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  void _showSystemNoticeDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('시스템 공지사항 발송'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '공지 제목',
                hintText: '예: 시스템 점검 안내',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '공지 내용',
                hintText: '사용자들에게 전달할 메시지를 입력하세요',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty && 
                  messageController.text.isNotEmpty) {
                try {
                  await AdminService.sendSystemNotification(
                    titleController.text,
                    messageController.text,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('공지사항이 발송되었습니다.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('발송 실패: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('발송'),
          ),
        ],
      ),
    );
  }
  
  void _createTestTodo() async {
    if (_testTodoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('테스트 할 일 제목을 입력하세요.')),
      );
      return;
    }
    
    final nextNotification = NotificationManager.calculateNextNotification(
      TimeZoneUtils.kstNow,
      _testNotificationInterval,
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('테스트 할 일 생성됨'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('제목: ${_testTodoController.text}'),
            Text('알림 간격: ${_testNotificationInterval.displayName}'),
            if (nextNotification != null)
              Text('다음 알림: ${nextNotification.toString().substring(0, 19)}'),
            const SizedBox(height: 16),
            const Text(
              '⚠️ 이것은 테스트 생성으로, 실제 할 일 목록에는 추가되지 않습니다.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
  
  void _testNotificationCalculation() {
    final results = <String, String>{};
    for (final interval in NotificationInterval.values) {
      if (interval == NotificationInterval.none) continue;
      
      final nextTime = NotificationManager.calculateNextNotification(
        TimeZoneUtils.kstNow,
        interval,
      );
      
      results[interval.displayName] = nextTime != null 
          ? nextTime.toString().substring(0, 19)
          : '계산 불가';
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림 시간 계산 결과'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '기준 시간: ${TimeZoneUtils.kstNow.toString().substring(0, 19)} (KST)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...results.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key),
                    Text(entry.value, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
  
  void _forceAIAnalysis() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('AI 분석을 실행하는 중...'),
          ],
        ),
      ),
    );
    
    try {
      final aiService = AIAnalysisService();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final analytics = await aiService.analyzeUserData(user.uid);
        final advice = await aiService.generatePersonalizedAdvice(analytics, []);
        
        if (context.mounted) {
          Navigator.pop(context); // 로딩 다이얼로그 닫기
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('AI 분석 완료'),
              content: SingleChildScrollView(
                child: Text(advice),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI 분석 실패: $e')),
        );
      }
    }
  }
  
  void _changeUserRole(String userId, String newRole) async {
    try {
      await AdminService.updateUserRole(userId, newRole);
      await _loadAdminData(); // 데이터 새로고침
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용자 역할이 $newRole로 변경되었습니다.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('역할 변경 실패: $e')),
        );
      }
    }
  }
  
  void _showUserDetail(String userId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('사용자 정보 로딩 중...'),
          ],
        ),
      ),
    );
    
    try {
      final userDetail = await AdminService.getUserDetail(userId);
      
      if (context.mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${userDetail.userData.displayName ?? userDetail.userData.email}'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('이메일: ${userDetail.userData.email}'),
                  Text('역할: ${userDetail.userData.role}'),
                  if (userDetail.userData.createdAt != null)
                    Text('가입일: ${userDetail.userData.createdAt!.toString().substring(0, 19)}'),
                  if (userDetail.userData.lastLogin != null)
                    Text('마지막 로그인: ${userDetail.userData.lastLogin!.toString().substring(0, 19)}'),
                  const Divider(),
                  Text('AI 분석 횟수: ${userDetail.aiAnalysisCount}회'),
                  if (userDetail.lastAnalysisDate != null)
                    Text('마지막 AI 분석: ${userDetail.lastAnalysisDate!.toString().substring(0, 19)}'),
                  const Divider(),
                  Text('최근 활동 데이터: ${userDetail.recentProgress.length}일'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용자 정보 로딩 실패: $e')),
        );
      }
    }
  }
}