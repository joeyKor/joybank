import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // File 클래스를 사용하기 위해 import

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  _MyPageScreenState createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  String _name = '';
  String _email = '';
  String _birthDate = '';
  String _school = '';
  File? _profileImage; // 프로필 이미지 파일
  bool _isLoading = true; // 로딩 상태 추가

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email') ?? '';
    final profileImagePath = prefs.getString('profileImagePath');

    print('MyPageScreen: Loading user data for email: $email'); // 디버깅: 이메일 출력

    if (profileImagePath != null) {
      setState(() {
        _profileImage = File(profileImagePath);
      });
    }

    if (email.isNotEmpty) {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first.data();
        print('MyPageScreen: User data found: $userData'); // 디버깅: 사용자 데이터 출력
        setState(() {
          _name = userData['name'] ?? '';
          _email = userData['email'] ?? '';
          _birthDate = userData['birthDate'] ?? '';
          _school = userData['school'] ?? '';
          _isLoading = false; // 데이터 로드 완료
        });
      } else {
        print('MyPageScreen: No user document found for email: $email'); // 디버깅: 사용자 문서 없음
        setState(() {
          _isLoading = false; // 사용자 데이터 없음
        });
      }
    } else {
      print('MyPageScreen: Email not found in SharedPreferences.'); // 디버깅: 이메일 없음
      setState(() {
        _isLoading = false; // 이메일 없음
      });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
      // 이미지 경로를 SharedPreferences에 저장
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('profileImagePath', image.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MY'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                        child: _profileImage == null ? const Icon(Icons.person, size: 50) : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(_name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text(_email, style: const TextStyle(color: Colors.grey)),
                  Text(_birthDate, style: const TextStyle(color: Colors.grey)),
                  Text(_school, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 30),
                  ListTile(
                    leading: const Icon(Icons.credit_card),
                    title: const Text('내 카드 관리'),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Icon(Icons.event_note),
                    title: const Text('내 금융 캘린더'),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Icon(Icons.headset_mic),
                    title: const Text('고객센터'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
    );
  }
}