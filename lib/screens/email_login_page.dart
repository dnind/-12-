import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';

class EmailLoginPage extends StatefulWidget {
  const EmailLoginPage({super.key});

  @override
  State<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      // 로컬 모드에서는 바로 홈으로 이동
      await Future.delayed(const Duration(milliseconds: 500)); // 로딩 시뮬레이션
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 실패: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      // 로컬 모드에서는 바로 홈으로 이동
      await Future.delayed(const Duration(milliseconds: 500)); // 로딩 시뮬레이션
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원가입 실패: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),

              // 로고/애니메이션
              SizedBox(
                height: 200,
                child: Lottie.asset('assets/welcome.json', errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.checklist, size: 100, color: Colors.blue);
                }),
              ),

              const SizedBox(height: 40),

              // 앱 제목
              Text(
                '마차',
                style: GoogleFonts.notoSans(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3748),
                ),
                textAlign: TextAlign.center,
              ),

              Text(
                '로컬 모드로 실행',
                style: GoogleFonts.notoSans(
                  fontSize: 16,
                  color: const Color(0xFF718096),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // 이메일 입력
              TextField(
                controller: _email,
                decoration: InputDecoration(
                  labelText: '이메일',
                  hintText: 'local@user.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 16),

              // 비밀번호 입력
              TextField(
                controller: _pw,
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  hintText: '아무거나 입력하세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                ),
                obscureText: true,
              ),

              const SizedBox(height: 24),

              // 로그인 버튼
              ElevatedButton(
                onPressed: _loading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4299E1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      '로그인',
                      style: GoogleFonts.notoSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
              ),

              const SizedBox(height: 12),

              // 회원가입 버튼
              OutlinedButton(
                onPressed: _loading ? null : _register,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '회원가입',
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                '로컬 모드에서는 로그인 없이 바로 사용할 수 있습니다',
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  color: const Color(0xFF718096),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }
}