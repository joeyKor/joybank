import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:joybank/pin_input_dialog.dart';
import 'package:joybank/main_screen.dart';
import 'package:joybank/custom_notification.dart'; // Custom notification for messages
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth 임포트

class PinResetScreen extends StatefulWidget {
  const PinResetScreen({super.key});

  @override
  State<PinResetScreen> createState() => _PinResetScreenState();
}

class _PinResetScreenState extends State<PinResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _schoolController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _birthDateController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndResetPin() async {
    if (_formKey.currentState!.validate()) {
      final enteredEmail = _emailController.text.trim();
      final enteredName = _nameController.text.trim();
      final enteredBirthDate = _birthDateController.text.trim();
      final enteredSchool = _schoolController.text.trim();

      // 현재 로그인된 사용자의 이메일 가져오기
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        showCustomNotification(context: context, message: '로그인된 사용자가 없습니다.');
        return;
      }

      if (currentUser.email != enteredEmail) {
        showCustomNotification(context: context, message: '입력하신 이메일이 현재 로그인된 계정과 다릅니다.');
        return;
      }

      try {
        // Firestore에서 사용자 정보 조회
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: enteredEmail)
            .get();

        if (usersSnapshot.docs.isEmpty) {
          showCustomNotification(context: context, message: '일치하는 사용자 정보가 없습니다.');
          return;
        }

        final userDoc = usersSnapshot.docs.first;
        final userData = userDoc.data();

        if (userData['name'] == enteredName &&
            userData['birthDate'] == enteredBirthDate &&
            userData['school'] == enteredSchool) {
          // 정보 일치 시 새 PIN 설정 다이얼로그 표시
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return PinInputDialog(
                                  onPinSet: (newPin) async {
                    // Firebase Firestore에 PIN 업데이트
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .update({'pin': newPin});

                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('userPin', newPin); // SharedPreferences에도 새 PIN 저장
                    showCustomNotification(context: context, message: '새로운 PIN이 설정되었습니다.');
                    Navigator.of(context).pop(); // PinInputDialog 닫기
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const MainScreen()),
                      (Route<dynamic> route) => false, // 모든 이전 라우트 제거
                    );
                  },
                isSettingPin: true,
              );
            },
          );
        } else {
          showCustomNotification(context: context, message: '입력하신 정보가 일치하지 않습니다.');
        }
      } catch (e) {
        showCustomNotification(context: context, message: 'PIN 재설정 중 오류 발생: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PIN 재설정'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '이메일',
                  hintText: '가입 시 사용한 이메일을 입력하세요',
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
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '이름',
                  hintText: '가입 시 사용한 이름을 입력하세요',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '이름을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _birthDateController,
                decoration: const InputDecoration(
                  labelText: '생년월일 (YYYY-MM-DD)',
                  hintText: '예: 1990-01-01',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '생년월일을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _schoolController,
                decoration: const InputDecoration(
                  labelText: '학교',
                  hintText: '가입 시 사용한 학교를 입력하세요',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '학교를 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _verifyAndResetPin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  '정보 확인 및 PIN 재설정',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
