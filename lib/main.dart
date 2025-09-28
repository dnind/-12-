import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'screens/home_page.dart';
import 'screens/email_login_page.dart';
import 'screens/ai_advice_page.dart';

// ───────────────── Entry
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 로케일 데이터 초기화 (한국어)
    await initializeDateFormatting('ko', null);

    // Firebase 초기화 (중복 초기화 방지)
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    print('초기화 오류: $e');
  }

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