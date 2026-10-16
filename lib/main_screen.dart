
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
  late PageController _accountPageController;
  late PageController _adPageController;
  String? _userId; // _email 대신 _userId 사용
  Stream<DocumentSnapshot>? _userStream;
  User? _currentUser; // 현재 로그인된 사용자 정보를 저장할 변수
  Stream<int>? _unreadNotificationsStream; // 읽지 않은 알림 수를 위한 스트림

  @override
  void initState() {
    super.initState();
    _accountPageController = PageController(viewportFraction: 0.9);
    _adPageController = PageController(viewportFraction: 0.9);
    _loadUserIdAndUserStream(); // 함수 이름 변경
    _getCurrentUser(); // 현재 사용자 정보 로드 함수 호출
  }

  void _getCurrentUser() {
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  void _loadUserIdAndUserStream() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId'); // userId 가져오기
      if (_userId != null) {
        _userStream = FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('accounts')
            .doc('main') // Listen to the main account document
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
    _accountPageController.dispose();
    _adPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const SizedBox(),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black54),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          StreamBuilder<int>(
            stream: _unreadNotificationsStream,
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.black54),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 11,
                      top: 11,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                ],
              );
            },
          ),          IconButton(
            icon: const Icon(Icons.person, color: Colors.black54),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => MyPageScreen()));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              _buildAccountsSection(context),
              const SizedBox(height: 30),
              _buildProductsSection(context),
              const SizedBox(height: 30),
              _buildMyDataSection(context),
              const SizedBox(height: 100), // 스피드다이얼 가림 및 모바일 하단 잘림 해결을 위한 마진 확보
            ],
          ),
        ),
      ),
      floatingActionButton: SpeedDial(
        backgroundColor: Colors.transparent,
        elevation: 0,
        activeBackgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
        activeChild: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 28),
        ),
        buttonSize: const Size(56.0, 56.0),
        visible: true,
        closeManually: false,
        curve: Curves.bounceIn,
        overlayColor: Colors.black,
        overlayOpacity: 0.4,
        onOpen: () => print('OPENING DIAL'),
        onClose: () => print('DIAL CLOSED'),
        tooltip: 'Speed Dial',
        heroTag: 'speed-dial-hero-tag',
        children: [
          SpeedDialChild(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            label: '이체',
            labelBackgroundColor: const Color(0xFF1E293B),
            labelStyle: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: Colors.white),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SendMoneyScreen()));
            },
          ),
          SpeedDialChild(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            label: '조이페이',
            labelBackgroundColor: const Color(0xFF1E293B),
            labelStyle: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: Colors.white),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const JoyPayScreen()));
            },
          ),
        ],
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            '내 계좌',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: StreamBuilder<DocumentSnapshot>(
            stream: _userStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData) {
                return const Center(child: Text('계좌 정보를 찾을 수 없습니다.'));
              }
              final accountData = snapshot.data!.data() as Map<String, dynamic>;
              final balance = accountData['balance'] ?? 0;
              final accountNumber = accountData['accountNumber'] ?? 'N/A';

              return PageView(
                controller: _accountPageController,
                children: [
                  _buildAccountCard(context, '입출금 계좌', accountNumber, '${NumberFormat('#,###').format(balance)}원', Colors.blue),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            '추천 상품',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: PageView(
            controller: _adPageController,
            children: [
              _buildAdBanner(
                '아플 때 힘이 되는 안심 보험',
                '실손, 자동차, 여행자 맞춤 설계',
                [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
                Icons.security_rounded,
                () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const InsuranceScreen()));
                },
              ),
              _buildAdBanner(
                '1분이면 끝나는 맞춤 대출',
                '내 신용점수 영향 없이 금리 비교',
                [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
                Icons.monetization_on_rounded,
                () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LoanScreen()));
                },
              ),
              _buildAdBanner(
                '똑똑한 자산 관리, 스마트 펀드',
                '소액으로 시작하는 글로벌 자산 투자',
                [const Color(0xFFF97316), const Color(0xFFEA580C)],
                Icons.trending_up_rounded,
                () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FundScreen()));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyDataSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            '마이데이터',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: PageView(
            children: [
              _buildMyDataCard(
                context,
                '나만을 위한 자산관리 서비스',
                Icons.analytics,
                Colors.purple,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AssetManagementScreen(initialTab: 0),
                    ),
                  );
                },
              ),
              _buildMyDataCard(
                context,
                '내 소비 패턴 분석하기',
                Icons.pie_chart,
                Colors.orange,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AssetManagementScreen(initialTab: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyDataCard(BuildContext context, String text, IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  Icon(icon, size: 40, color: Colors.white.withOpacity(0.8)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, String accountType, String accountNumber, String balance, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [color, color == Colors.blue ? Colors.blue.shade700 : Colors.red.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        accountType,
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.more_vert, color: Colors.white70, size: 22),
                        onPressed: () {
                          _showAccountSettings(context, accountType, accountNumber, balance);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: accountNumber));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('계좌번호가 클립보드에 복사되었습니다: $accountNumber'),
                          backgroundColor: Colors.blue.shade800,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            accountNumber,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      balance,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(top: 3.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildActionButton(context, '거래내역', Icons.history, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const TransactionHistoryScreen()),
                      );
                    }),
                    _buildActionButton(context, '송금하기', Icons.send, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SendMoneyScreen()),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String title, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Theme.of(context).primaryColor),
      label: Text(title, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  Widget _buildAdBanner(String title, String subtitle, List<Color> colors, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          elevation: 4,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // 우측 배경 아이콘 효과
                Positioned(
                  right: -15,
                  bottom: -15,
                  child: Icon(
                    icon,
                    size: 130,
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
                // 콘텐츠 텍스트
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
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
