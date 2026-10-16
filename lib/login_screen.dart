import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:joybank/main_screen.dart';
import 'package:joybank/sign_up_screen.dart';
import 'package:joybank/pin_reset_screen.dart'; // PinResetScreen 임포트
import 'package:firebase_auth/firebase_auth.dart';
import 'package:joybank/pin_input_dialog.dart'; // PinInputDialog 임포트
import 'package:joybank/admin_screen.dart'; // AdminScreen 임포트
import 'custom_notification.dart';

class LoginScreen extends StatefulWidget {
  final bool fromForgotPin; // PIN 잊어버리기 경로에서 왔는지 여부

  const LoginScreen({super.key, this.fromForgotPin = false});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  bool _obscurePin = true;

  void _login() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text;
      final password = _pinController.text; // PIN을 비밀번호로 사용

      try {
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', userCredential.user!.uid); // 사용자 ID 저장
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userPin', password); // PIN 저장
        await prefs.setString('email', email); // 이메일 저장

        // 관리자 계정 확인
        if (email == 'admin@joybank.com' && password == '369369') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminScreen()), // AdminScreen으로 이동
          );
          return; // 관리자 로그인 성공 시 일반 로그인 로직 건너뛰기
        }

        if (widget.fromForgotPin) {
          // PIN 잊어버리기 경로에서 왔다면 새 PIN 설정 다이얼로그 표시
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (BuildContext context) {
              return PinInputDialog(
                onPinSet: (newPin) async {
                  // 새 PIN 저장 로직
                  await prefs.setString('userPin', newPin);
                  showCustomNotification(
                    context: context,
                    message: '새로운 PIN이 설정되었습니다.',
                  );
                  Navigator.of(context).pop(); // PinInputDialog 닫기
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const MainScreen()),
                  ); // 메인 화면으로 이동
                },
                isSettingPin: true, // PIN 설정 모드
              );
            },
          );
        } else {
          // 일반 로그인이라면 메인 화면으로 이동
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      } on FirebaseAuthException catch (e) {
        String message;
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
          message = '이메일 주소 또는 PIN 비밀번호가 올바르지 않습니다.';
        } else if (e.code == 'invalid-email') {
          message = '올바르지 않은 이메일 형식입니다.';
        } else if (e.code == 'too-many-requests') {
          message = '너무 많은 로그인 시도가 발생했습니다. 잠시 후 다시 시도해주세요.';
        } else {
          message = '로그인에 실패했습니다. 입력한 정보를 확인해주세요.';
        }
        showCustomNotification(
          context: context,
          message: message,
        );
      } catch (e) {
        showCustomNotification(
          context: context,
          message: '로그인 중 오류가 발생했습니다. 다시 시도해주세요.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // 상단 은은한 민트 톤 그라데이션 배경
          Container(
            height: 280,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE4F4ED),
                  Color(0xFFF1F8F5),
                  Color(0xFFF8FAFC),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 조이뱅크 로고 & 타이틀
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: Color(0xFF005BAC),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x33005BAC),
                            blurRadius: 14,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'JB',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '조이뱅크',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF191F28),
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '쉽고 안전한 모바일 금융',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8B95A1),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // 로그인 폼 카드
                    Container(
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '이메일 주소',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333D4B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF191F28),
                              ),
                              decoration: InputDecoration(
                                hintText: 'example@email.com',
                                hintStyle: const TextStyle(color: Color(0xFFB0B8C1), fontSize: 14),
                                prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20, color: Color(0xFF8B95A1)),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFF005BAC), width: 1.5),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '이메일을 입력해주세요.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'PIN 비밀번호',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333D4B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _pinController,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF191F28),
                                letterSpacing: 2,
                              ),
                              decoration: InputDecoration(
                                hintText: '6자리 숫자',
                                hintStyle: const TextStyle(color: Color(0xFFB0B8C1), fontSize: 14, letterSpacing: 0),
                                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: Color(0xFF8B95A1)),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: const Color(0xFF8B95A1),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePin = !_obscurePin;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFF005BAC), width: 1.5),
                                ),
                                counterText: '',
                              ),
                              keyboardType: TextInputType.number,
                              obscureText: _obscurePin,
                              maxLength: 6,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'PIN 번호를 입력해주세요.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 26),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF005BAC),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  '로그인',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 하단 보조 메뉴 (PIN 재설정 | 계좌 개설)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const PinResetScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Text(
                              'PIN 재설정',
                              style: TextStyle(
                                color: Color(0xFF4E5968),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 12,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          color: const Color(0xFFCBD5E1),
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SignUpScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Text(
                              '계좌 개설(회원가입)',
                              style: TextStyle(
                                color: Color(0xFF005BAC),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
