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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'JoyBank',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 48),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: '이메일 주소',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '이메일을 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _pinController,
                        decoration: InputDecoration(
                          labelText: 'PIN 비밀번호',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePin ? Icons.visibility : Icons.visibility_off,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePin = !_obscurePin;
                              });
                            },
                          ),
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
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('로그인', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PinResetScreen()),
                        );
                      },
                      child: const Text(
                        'PIN 재설정',
                        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Text('  |  ', style: TextStyle(color: Colors.grey)),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SignUpScreen()),
                        );
                      },
                      child: const Text(
                        '계좌 개설',
                        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
