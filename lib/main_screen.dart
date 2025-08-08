
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

import 'my_page_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      backgroundColor: Colors.grey[100],
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
          ),
          
          IconButton(
            icon: const Icon(Icons.person, color: Colors.black54),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPageScreen()));
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
            ],
          ),
        ),
      ),
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
          height: 225,
          child: StreamBuilder<DocumentSnapshot>(
            stream: _userStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData) {
                return const Center(child: Text('No account data found.'));
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
              _buildAdBanner('보험 광고', '똑똑한 보험 관리', Colors.teal, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const InsuranceScreen()));
              }),
              _buildAdBanner('대출 광고', '내게 맞는 대출 찾기', Colors.indigo, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoanScreen()));
              }),
              _buildAdBanner('펀드 광고', '안전한 자산 증식', Colors.deepOrange, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FundScreen()));
              }),
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
              _buildMyDataCard(context, '나만을 위한 자산관리 서비스', Icons.analytics, Colors.purple),
              _buildMyDataCard(context, '내 소비 패턴 분석하기', Icons.pie_chart, Colors.orange),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyDataCard(BuildContext context, String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    );
  }

  Widget _buildAccountCard(BuildContext context, String accountType, String accountNumber, String balance, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24.0),
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
                  Text(
                    accountType,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    accountNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
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

  Widget _buildAdBanner(String title, String subtitle, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          elevation: 6,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            color: color,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
