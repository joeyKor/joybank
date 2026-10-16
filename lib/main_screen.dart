
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'transaction_history_screen.dart';
import 'send_money_screen.dart'; // 송금하기 화면 임포트
import 'notification_screen.dart'; // 알림 화면 임포트

import 'insurance_screen.dart';
import 'loan_screen.dart';
import 'fund_screen.dart'; // FundScreen import 다시 추가
import 'settings_screen.dart';

import 'package:joybank/my_page_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'joy_pay_screen.dart';
import 'asset_management_screen.dart';
import 'package:flutter/services.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late PageController _adPageController;
  String? _userId;
  Stream<DocumentSnapshot>? _userStream;
  User? _currentUser;
  Stream<int>? _unreadNotificationsStream;

  // NH 스타일 UI 상태 변수
  bool _isBalanceHidden = false;
  int _adPageIndex = 0;
  int _selectedBottomIndex = 2; // 기본: 홈 탭

  @override
  void initState() {
    super.initState();
    _adPageController = PageController(viewportFraction: 0.92);
    _adPageController.addListener(() {
      final page = _adPageController.page?.round() ?? 0;
      if (page != _adPageIndex) {
        setState(() {
          _adPageIndex = page;
        });
      }
    });
    _loadUserIdAndUserStream();
    _getCurrentUser();
  }

  void _getCurrentUser() {
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  void _loadUserIdAndUserStream() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId');
      if (_userId != null) {
        _userStream = FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('accounts')
            .doc('main')
            .snapshots();

        _unreadNotificationsStream = FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('notifications')
            .where('read', isEqualTo: false)
            .snapshots()
            .map((snapshot) => snapshot.docs.length);
      }
    });
  }

  @override
  void dispose() {
    _adPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE4F4ED),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFF005BAC),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'JB',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '조이뱅크',
              style: TextStyle(
                color: Color(0xFF191F28),
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded, color: Color(0xFF333D4B), size: 24),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => MyPageScreen()));
            },
          ),
          StreamBuilder<int>(
            stream: _unreadNotificationsStream,
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF333D4B), size: 24),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Color(0xFF333D4B), size: 24),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // 상단 은은한 민트 톤 그라데이션 배경
          Container(
            height: 240,
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
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAccountsSection(context),
                const SizedBox(height: 28),
                _buildProductsSection(context),
                const SizedBox(height: 28),
                _buildMyDataSection(context),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedBottomIndex,
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF191F28),
          unselectedItemColor: const Color(0xFF8B95A1),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: '상품',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart_outline_rounded),
              activeIcon: Icon(Icons.pie_chart_rounded),
              label: '마이데이터',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_filled),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner_rounded),
              activeIcon: Icon(Icons.qr_code_scanner_rounded),
              label: '조이페이',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: '마이페이지',
            ),
          ],
          onTap: (index) {
            if (index == 0) {
              _showProductsModal(context);
            } else if (index == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AssetManagementScreen(initialTab: 0)),
              );
            } else if (index == 2) {
              setState(() => _selectedBottomIndex = 2);
            } else if (index == 3) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const JoyPayScreen()));
            } else if (index == 4) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => MyPageScreen()));
            }
          },
        ),
      ),
    );
  }

  // --- 통장 관리 설정창 (바텀 시트) ---
  void _showAccountSettings(BuildContext context, String accountType, String accountNumber, String balance) {
    showModalBottomSheet(
      context: context,
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
                '통장 관리',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 20),
              
              // 통장 기본 정보
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('상품명', '조이 스마트 입출금통장'),
                    const Divider(height: 16),
                    _buildInfoRow('계좌번호', accountNumber),
                    const Divider(height: 16),
                    _buildInfoRow('적용금리', '연 1.20% (세전)'),
                    const Divider(height: 16),
                    _buildInfoRow('개설일자', '2026년 06월 15일'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // 액션 버튼
              ListTile(
                leading: const Icon(Icons.file_copy_rounded, color: Colors.blue),
                title: const Text('통장사본 보기', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('계좌 개설 증명용 통장사본 확인 및 이미지 안내'),
                onTap: () {
                  Navigator.pop(context);
                  _showAccountCertificate(context, accountType, accountNumber, balance);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --- 통장사본 다이얼로그 (증서 디자인) ---
  void _showAccountCertificate(BuildContext context, String accountType, String accountNumber, String balance) {
    final GlobalKey boundaryKey = GlobalKey();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Certificate',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            contentPadding: EdgeInsets.zero,
            content: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(_userId!).get(),
              builder: (context, snapshot) {
                String ownerName = '조이 고객';
                if (snapshot.hasData && snapshot.data!.exists) {
                  ownerName = snapshot.data!.get('name') ?? '조이 고객';
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RepaintBoundary(
                      key: boundaryKey,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 상단 헤더
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1E293B),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(24),
                                  topRight: Radius.circular(24),
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.account_balance_rounded, color: Colors.amber, size: 32),
                                  const SizedBox(height: 8),
                                  const Text(
                                    '계좌 개설 확인서',
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'JoyBank Account Certificate',
                                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, letterSpacing: 0.5),
                                  ),
                                ],
                              ),
                            ),
                            
                            // 서류 본문 영역
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                children: [
                                  // 격자 형태의 증서 정보
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildCertRow('예 금 주', ownerName),
                                        const Divider(height: 20),
                                        _buildCertRow('계좌번호', accountNumber),
                                        const Divider(height: 20),
                                        _buildCertRow('상 품 명', '조이 스마트 입출금통장'),
                                        const Divider(height: 20),
                                        _buildCertRow('신규일자', '2026년 06월 15일'),
                                        const Divider(height: 20),
                                        _buildCertRow('발행일자', DateFormat('yyyy년 MM월 dd일').format(DateTime.now())),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // 증명 안내 문구
                                  Text(
                                    '위 계좌는 조이뱅크(JoyBank)에 개설된 예금거래용 계좌임을 확인합니다.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.w500, height: 1.5),
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // 발행 기관 및 직인 배치
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        '조이뱅크 주식회사',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                      ),
                                      const SizedBox(width: 12),
                                      // 빨간색 원형 직인 위젯
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.red.shade700, width: 2.5),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '조이\n뱅크',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              height: 1.1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // 하단 버튼 영역
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border(top: BorderSide(color: Colors.grey.shade200)),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      child: SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  try {
                                    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                                    if (boundary == null) return;
                                    
                                    final image = await boundary.toImage(pixelRatio: 3.0);
                                    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                                    if (byteData == null) return;
                                    
                                    final bytes = byteData.buffer.asUint8List();
                                    await Gal.putImageBytes(bytes);
                                    
                                    if (context.mounted) {
                                      _showSaveResultDialog(context, true);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      _showSaveResultDialog(context, false, errorMessage: e.toString());
                                    }
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF1E293B), width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.download_rounded, color: Color(0xFF1E293B), size: 18),
                                    SizedBox(width: 4),
                                    Text('이미지 저장', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E293B),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: const Text('닫기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showSaveResultDialog(BuildContext context, bool success, {String? errorMessage}) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  success ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: success ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                  size: 56,
                ),
                const SizedBox(height: 16),
                Text(
                  success ? '저장 완료' : '저장 실패',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  success
                      ? '계좌 개설 확인서가 사진첩(갤러리)에 안전하게 저장되었습니다.'
                      : '오류가 발생했습니다.\n${errorMessage ?? ""}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text(
                      '확인',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCertRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상단 헤더: 조이뱅크 / 전체계좌 >
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    '조이뱅크',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF191F28),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00A86B),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  // 전체 계좌 / 통장 관리 바텀시트
                  _userStream?.first.then((snapshot) {
                    if (snapshot.exists) {
                      final accountData = snapshot.data() as Map<String, dynamic>;
                      final balance = accountData['balance'] ?? 0;
                      final accountNumber = accountData['accountNumber'] ?? 'N/A';
                      _showAccountSettings(
                        context,
                        '입출금 계좌',
                        accountNumber,
                        '${NumberFormat('#,###').format(balance)}원',
                      );
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '전체계좌',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        StreamBuilder<DocumentSnapshot>(
          stream: _userStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 200,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(child: CircularProgressIndicator()),
              );
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Container(
                height: 200,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(child: Text('계좌 정보를 찾을 수 없습니다.')),
              );
            }
            final accountData = snapshot.data!.data() as Map<String, dynamic>;
            final balance = accountData['balance'] ?? 0;
            final accountNumber = accountData['accountNumber'] ?? 'N/A';

            return _buildMainAccountCard(context, accountNumber, balance);
          },
        ),
      ],
    );
  }

  // --- NH 스타일 메인 계좌 카드 ---
  Widget _buildMainAccountCard(BuildContext context, String accountNumber, dynamic balance) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2EBF0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
            child: Row(
              children: [
                // 파란색 원형 로고 심볼 (NH 느낌)
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFF005BAC),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'JB',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      _showAccountSettings(
                        context,
                        '입출금 계좌',
                        accountNumber,
                        '${NumberFormat('#,###').format(balance)}원',
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '조이 스마트 입출금통장',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF191F28),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                // 새로고침 아이콘
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 22, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('잔액 정보가 갱신되었습니다.'),
                        duration: Duration(milliseconds: 900),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                // 더보기 점 세 개 (통장 관리)
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, size: 22, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                  onPressed: () {
                    _showAccountSettings(
                      context,
                      '입출금 계좌',
                      accountNumber,
                      '${NumberFormat('#,###').format(balance)}원',
                    );
                  },
                ),
              ],
            ),
          ),
          // 계좌번호 표시 및 복사
          Padding(
            padding: const EdgeInsets.only(left: 64, top: 2),
            child: InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: accountNumber));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('계좌번호가 복사되었습니다: $accountNumber'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '조이뱅크 $accountNumber',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8B95A1),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF8B95A1)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          // 중앙 잔액 및 잔액 가리기 🔒 아이콘
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isBalanceHidden ? '••••••원' : '${NumberFormat('#,###').format(balance)}원',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF191F28),
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isBalanceHidden = !_isBalanceHidden;
                    });
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isBalanceHidden ? Icons.lock_rounded : Icons.lock_open_rounded,
                      size: 17,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 카드 하단 2분할 버튼 (거래내역 | 송금)
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
                    );
                  },
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(22)),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 17),
                    child: Center(
                      child: Text(
                        '거래내역',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333D4B),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SendMoneyScreen()),
                    );
                  },
                  borderRadius: const BorderRadius.only(bottomRight: Radius.circular(22)),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 17),
                    child: Center(
                      child: Text(
                        '송금',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF191F28),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 추천 상품 섹션 (NH 콕추천 스타일) ---
  Widget _buildProductsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '추천 상품',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191F28),
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_adPageIndex + 1}/3',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: PageView(
            controller: _adPageController,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildAdBanner(
                title: '아플 때 힘이 되는 안심 보험',
                subtitle: '실손, 자동차, 여행자 맞춤 설계',
                tag: '보장 케어',
                icon: Icons.health_and_safety_rounded,
                iconColor: const Color(0xFF005BAC),
                iconBg: const Color(0xFFEAF2FF),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const InsuranceScreen()));
                },
              ),
              _buildAdBanner(
                title: '1분이면 끝나는 맞춤 대출',
                subtitle: '내 신용점수 영향 없이 한도·금리 비교',
                tag: '간편 한도조회',
                icon: Icons.account_balance_rounded,
                iconColor: const Color(0xFF7C3AED),
                iconBg: const Color(0xFFF3E8FF),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LoanScreen()));
                },
              ),
              _buildAdBanner(
                title: '똑똑한 자산 관리 스마트 펀드',
                subtitle: '소액으로 시작하는 글로벌 자산 투자',
                tag: '인기 투자',
                icon: Icons.trending_up_rounded,
                iconColor: const Color(0xFFEA580C),
                iconBg: const Color(0xFFFFEDD5),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FundScreen()));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 세련된 추천 상품 배너 카드 ---
  Widget _buildAdBanner({
    required String title,
    required String subtitle,
    required String tag,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: iconColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF191F28),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8B95A1),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: iconColor, size: 30),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 마이데이터 & 자산관리 섹션 ---
  Widget _buildMyDataSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            '자산관리 & 마이데이터',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF191F28),
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: _buildMyDataActionCard(
                  title: '나만의 자산관리',
                  subtitle: '포트폴리오 분석',
                  icon: Icons.pie_chart_rounded,
                  iconColor: const Color(0xFF2563EB),
                  iconBg: const Color(0xFFEFF6FF),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AssetManagementScreen(initialTab: 0)),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMyDataActionCard(
                  title: '소비 패턴 분석',
                  subtitle: '이번달 소비 리포트',
                  icon: Icons.receipt_long_rounded,
                  iconColor: const Color(0xFF059669),
                  iconBg: const Color(0xFFECFDF5),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AssetManagementScreen(initialTab: 1)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyDataActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF191F28),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8B95A1),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 하단 바 '상품' 탭 클릭 시 상품 목록 모달 ---
  void _showProductsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
              const SizedBox(height: 18),
              const Text(
                '금융 상품 둘러보기',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF191F28)),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.health_and_safety_rounded, color: Color(0xFF2563EB)),
                ),
                title: const Text('안심 보험', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('실손, 자동차, 여행자 보험 맞춤 설계'),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF8B95A1)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const InsuranceScreen()));
                },
              ),
              const Divider(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_rounded, color: Color(0xFF7C3AED)),
                ),
                title: const Text('맞춤 대출', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('신용점수 영향 없는 한도·금리 비교'),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF8B95A1)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LoanScreen()));
                },
              ),
              const Divider(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDD5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.trending_up_rounded, color: Color(0xFFEA580C)),
                ),
                title: const Text('스마트 펀드', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('글로벌 우량 자산 분산 투자'),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF8B95A1)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FundScreen()));
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
