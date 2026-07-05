import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:joybank/login_screen.dart';
import 'package:joybank/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:joybank/pin_input_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('email');

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  void _showPasswordDialog(BuildContext context) {
    TextEditingController passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('비밀번호 입력'),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '비밀번호를 입력하세요'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('확인'),
              onPressed: () async {
                if (passwordController.text == '111111') {
                  bool success = await _depositMoney(context);
                  if (success && mounted) {
                    Navigator.of(context).pop();
                  }
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('비밀번호가 틀렸습니다.')));
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool> _depositMoney(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');

    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인된 사용자 ID를 찾을 수 없습니다.')));
      return false;
    }

    try {
      print('Attempting to deposit money for user: $userId');
      await FirebaseService.depositMoney(userId, 100000);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('100,000원이 입금되었습니다.')));
      }
      print('Deposit successful.');
      return true;
    } catch (e) {
      print('Deposit failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('입금 실패: $e')));
      }
      return false;
    }
  }



  // --- 알림 설정 바텀 시트 ---
  void _showNotificationSettings(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    bool pushEnabled = prefs.getBool('pushEnabled') ?? true;
    bool depositEnabled = prefs.getBool('depositEnabled') ?? true;
    bool benefitEnabled = prefs.getBool('benefitEnabled') ?? false;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '알림 설정',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile.adaptive(
                    title: const Text('앱 푸시 알림 수신', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('조이뱅크 앱에서 보내는 모든 알림의 마스터 스위치'),
                    activeColor: Colors.blue,
                    value: pushEnabled,
                    onChanged: (val) async {
                      await prefs.setBool('pushEnabled', val);
                      setModalState(() {
                        pushEnabled = val;
                      });
                    },
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    title: const Text('입출금 및 거래 알림', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('계좌 이체, 송금 등 금융 거래 내역 발생 시 실시간 알림'),
                    activeColor: Colors.blue,
                    value: depositEnabled && pushEnabled,
                    onChanged: !pushEnabled
                        ? null
                        : (val) async {
                            await prefs.setBool('depositEnabled', val);
                            setModalState(() {
                              depositEnabled = val;
                            });
                          },
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    title: const Text('혜택 및 마케팅 정보 알림', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('나를 위한 추천 대출/보험/자산 케어 신규 소식 수신'),
                    activeColor: Colors.blue,
                    value: benefitEnabled && pushEnabled,
                    onChanged: !pushEnabled
                        ? null
                        : (val) async {
                            await prefs.setBool('benefitEnabled', val);
                            setModalState(() {
                              benefitEnabled = val;
                            });
                          },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [

          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('알림 설정'),
            onTap: () => _showNotificationSettings(context),
          ),
          const Divider(),
          GestureDetector(
            onLongPress: () {
              _showPasswordDialog(context);
            },
            child: const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('앱 정보'),
              subtitle: Text('Version 1.0.0'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('로그아웃', style: TextStyle(color: Colors.red)),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
