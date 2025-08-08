import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:joybank/main_screen.dart';
import 'package:joybank/sign_up_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:joybank/pin_input_dialog.dart'; // PinInputDialog 임포트

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

        if (widget.fromForgotPin) {
          // PIN 잊어버리기 경로에서 왔다면 새 PIN 설정 다이얼로그 표시
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return PinInputDialog(
                onPinSet: (newPin) async {
                  // 새 PIN 저장 로직
                  await prefs.setString('userPin', newPin);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('새로운 PIN이 설정되었습니다.')),
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
        if (e.code == 'user-not-found') {
          message = '해당 이메일의 사용자를 찾을 수 없습니다.';
        } else if (e.code == 'wrong-password') {
          message = '비밀번호가 틀렸습니다.';
        } else {
          message = '로그인 실패: ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 중 오류 발생: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
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
                          labelText: 'Email',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _pinController,
                        decoration: InputDecoration(
                          labelText: 'PIN',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 6,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your PIN';
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
                  child: const Text('Login', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SignUpScreen()),
                    );
                  },
                  child: const Text(
                    'Don\'t have an account? Sign Up',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}