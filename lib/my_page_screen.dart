import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  _MyPageScreenState createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  String _name = '';
  String _email = '';
  String _birthDate = '';
  File? _profileImage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email') ?? '';
    final profileImagePath = prefs.getString('profileImagePath');

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
        setState(() {
          _name = userData['name'] ?? '';
          _email = userData['email'] ?? '';
          _birthDate = userData['birthDate'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
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
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('profileImagePath', image.path);
    }
  }

  // --- 고객센터 바텀시트 ---
  void _showCustomerService(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
          ),
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
                '고객지원 센터',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 20),
              
              // 24시간 대표전화 카드
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 30),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('조이뱅크 24시간 콜센터', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          SizedBox(height: 4),
                          Text('1588-1234', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showCallDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue.shade800,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('전화연결', style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // FAQ 섹션
              const Text('자주 묻는 질문 (FAQ)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12),
              _buildFaqItem('Q. PIN 번호를 분실했습니다. 어떻게 하나요?', '로그인 화면 하단의 [PIN 재설정] 메뉴에서 이메일, 이름, 생년월일 본인 확인 단계를 거쳐 안전하게 재설정하실 수 있습니다.'),
              const Divider(),
              _buildFaqItem('Q. 1일 송금 한도를 상향하고 싶습니다.', '금융 안전 수칙에 따라 한도 상향은 가까운 조이뱅크 영업점 대출/예금 창구를 신분증을 지참하여 방문해 주시면 신속히 처리해 드립니다.'),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              answer,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.5),
            ),
          )
        ],
      ),
    );
  }

  void _showCallDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text('대표 고객센터 연결 중', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('조이뱅크 24시간 상담원에게 연결하고 있습니다.\n\n전화번호: 1588-1234', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('연결 취소', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('마이페이지', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // 1. 프로필 카드 영역 (Rich Aesthetics)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.015),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 54,
                              backgroundColor: Colors.blue.shade50,
                              backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                              child: _profileImage == null
                                  ? Icon(Icons.person_rounded, size: 54, color: Colors.blue.shade600)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1E293B),
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _name.isNotEmpty ? _name : '조이 고객님',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        
                        // 이메일 및 생년월일 칩 데코
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.email_outlined, size: 12, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(_email, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.cake_outlined, size: 12, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(_birthDate, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. 관리 메뉴 리스트
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '나의 금융 정보 관리',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.headset_mic_rounded, color: Colors.blue),
                          title: const Text('고객센터', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('24시간 헬프센터 전화 상담 및 주요 FAQ 안내'),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                          onTap: () => _showCustomerService(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}