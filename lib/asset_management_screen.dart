import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'fund_screen.dart';

class AssetManagementScreen extends StatefulWidget {
  final int initialTab; // 0: 자산관리, 1: 소비패턴

  const AssetManagementScreen({super.key, this.initialTab = 0});

  @override
  State<AssetManagementScreen> createState() => _AssetManagementScreenState();
}

class _AssetManagementScreenState extends State<AssetManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _userName = '고객';
  String _userId = '';
  int _cashBalance = 5000000; // 기본 현금 잔액
  bool _isLoading = true;

  // 자산 데이터
  int _fundAsset = 0;
  int _stockAsset = 0;
  int _foreignAsset = 0;

  // 챌린지 상태 변수
  bool _foodChallengeActive = false;
  bool _coffeeChallengeActive = false;
  double _foodProgress = 0.45;
  double _coffeeProgress = 0.85;

  StreamSubscription<QuerySnapshot>? _transactionsSubscription;
  int _currentMonthSpending = 0;
  int _lastMonthSpending = 780000;
  int _budgetAmount = 1000000;
  int _foodSpending = 0;
  int _shoppingSpending = 0;
  int _transportSpending = 0;
  int _etcSpending = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _transactionsSubscription?.cancel();
    super.dispose();
  }

  void _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';

      if (userId.isNotEmpty) {
        // 1. 유저 이름 정보 가져오기
        final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (doc.exists) {
          _userName = doc.data()?['name'] ?? '고객';
        }

        // 2. 실시간 계좌 잔액 가져오기 (단발성)
        final accountDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('accounts')
            .doc('main')
            .get();

        if (accountDoc.exists) {
          _cashBalance = accountDoc.data()?['balance'] ?? 5000000;
        }

        // 3. 실제 보유한 펀드 총액 계산하기
        int userFundTotal = 0;
        final fundsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('funds')
            .get();

        for (var fDoc in fundsSnapshot.docs) {
          userFundTotal += (fDoc.data()['amount'] ?? 0) as int;
        }

        // 3-1. 실제 보유한 주식 총액 계산하기 (데이터가 없으면 Firestore에 기본 더미 생성)
        int userStockTotal = 0;
        final stocksRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('stocks');
        var stocksSnapshot = await stocksRef.get();
        if (stocksSnapshot.docs.isEmpty) {
          await stocksRef.doc('samsung').set({'name': '삼성전자', 'amount': 1500000});
          await stocksRef.doc('apple').set({'name': '애플', 'amount': 800000});
          stocksSnapshot = await stocksRef.get();
        }
        for (var sDoc in stocksSnapshot.docs) {
          userStockTotal += (sDoc.data()['amount'] ?? 0) as int;
        }

        // 3-2. 실제 보유한 외화 총액 계산하기 (데이터가 없으면 Firestore에 기본 더미 생성)
        int userForeignTotal = 0;
        final foreignRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('foreign_assets');
        var foreignSnapshot = await foreignRef.get();
        if (foreignSnapshot.docs.isEmpty) {
          await foreignRef.doc('usd').set({'name': '미국 달러 (USD)', 'amount': 500000});
          await foreignRef.doc('jpy').set({'name': '일본 엔화 (JPY)', 'amount': 200000});
          foreignSnapshot = await foreignRef.get();
        }
        for (var frDoc in foreignSnapshot.docs) {
          userForeignTotal += (frDoc.data()['amount'] ?? 0) as int;
        }

        // 4. 실시간 거래 내역 구독하여 이번달 소비 계산
        _transactionsSubscription?.cancel();
        _transactionsSubscription = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('transactions')
            .snapshots()
            .listen((snapshot) {
          _calculateSpending(snapshot.docs);
        });

        setState(() {
          _userId = userId;
          _fundAsset = userFundTotal;
          _stockAsset = userStockTotal;
          _foreignAsset = userForeignTotal;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data in AssetManagementScreen: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _calculateSpending(List<QueryDocumentSnapshot> docs) {
    int food = 0;
    int shopping = 0;
    int transport = 0;
    int etc = 0;
    int totalSpending = 0;

    final now = DateTime.now();
    final startOfThisMonth = DateTime(now.year, now.month, 1);

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final isDeposit = data['is_deposit'] ?? false;

      // 지출(출금/결제)인 것만 계산
      if (isDeposit) continue;

      final timestamp = data['timestamp'] as Timestamp?;
      if (timestamp == null) continue;

      final date = timestamp.toDate();
      // 이번 달 지출만 필터링
      if (date.isBefore(startOfThisMonth)) continue;

      final amount = (data['amount'] ?? 0) as num;
      final description = (data['description'] ?? '').toString();
      final type = (data['type'] ?? '').toString();

      final intAmt = amount.toInt();
      totalSpending += intAmt;

      // 상호명/설명 분석을 통한 자동 분류
      if (description.contains('CU') ||
          description.contains('마트') ||
          description.contains('카페') ||
          description.contains('커피') ||
          description.contains('스타벅스') ||
          description.contains('식당') ||
          description.contains('편의점') ||
          type == 'PAYMENT') {
        food += intAmt;
      } else if (description.contains('쇼핑') ||
                 description.contains('쿠팡') ||
                 description.contains('패션') ||
                 description.contains('무신사')) {
        shopping += intAmt;
      } else if (description.contains('택시') ||
                 description.contains('버스') ||
                 description.contains('교통') ||
                 description.contains('지하철')) {
        transport += intAmt;
      } else {
        etc += intAmt;
      }
    }

    setState(() {
      _currentMonthSpending = totalSpending;
      _foodSpending = food;
      _shoppingSpending = shopping;
      _transportSpending = transport;
      _etcSpending = etc;
    });
  }

  @override
  Widget build(BuildContext context) {
    int totalAsset = _cashBalance + _fundAsset + _stockAsset + _foreignAsset;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('마이 자산케어', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black87,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4F46E5),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF4F46E5),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(text: '자산 포트폴리오'),
            Tab(text: '스마트 소비 분석'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAssetTab(totalAsset),
                _buildSpendingTab(),
              ],
            ),
    );
  }

  // --- 1. 자산 포트폴리오 탭 ---
  Widget _buildAssetTab(int totalAsset) {
    List<double> chartValues = [
      _cashBalance.toDouble(),
      _fundAsset.toDouble(),
      _stockAsset.toDouble(),
      _foreignAsset.toDouble()
    ];
    List<Color> chartColors = [
      const Color(0xFF3B82F6), // 파랑 (현금)
      const Color(0xFF10B981), // 초록 (펀드)
      const Color(0xFF8B5CF6), // 보라 (주식)
      const Color(0xFFF59E0B), // 노랑 (외화)
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카드: 총 자산 종합 리포트
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withOpacity(0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$_userName님의 순자산 종합',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Joy MyData', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${NumberFormat('#,###').format(totalAsset)} 원',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                Divider(color: Colors.white.withOpacity(0.15)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('보유한 계좌/자산', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                    const Text('총 4개 연결됨', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 자산 비중 원형 그래프 카드
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0.5,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('자산 포트폴리오 비중', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      // Custom Paint 도넛 그래프
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: CustomPaint(
                          painter: DonutChartPainter(values: chartValues, colors: chartColors),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text('투자 비중', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                SizedBox(height: 2),
                                Text('스마트형', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 28),
                      // 범례 정보
                      Expanded(
                        child: Column(
                          children: [
                            _buildLegendItem(chartColors[0], '현금/예금', _cashBalance, totalAsset),
                            _buildLegendItem(chartColors[1], '투자 펀드', _fundAsset, totalAsset),
                            _buildLegendItem(chartColors[2], '보유 주식', _stockAsset, totalAsset),
                            _buildLegendItem(chartColors[3], '외화 자산', _foreignAsset, totalAsset),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // AI 맞춤 투자 케어 어드바이스
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFEFF6FF), Colors.blue.shade50.withOpacity(0.4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology_rounded, color: Colors.blue.shade700, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'AI 자산 맞춤 처방전',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '현재 $_userName님의 포트폴리오는 현금성 자산 비중이 높은 편입니다. 조이뱅크의 인기 글로벌 펀드 상품을 활용해 연 8% 이상의 기대수익률 모델을 설계해보는 것을 추천합니다.',
                  style: TextStyle(fontSize: 13, color: Colors.blue.shade900, height: 1.5),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FundScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('추천 펀드 구경하기', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, int val, int total) {
    double ratio = total > 0 ? (val / total) * 100 : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          Text(
            '${ratio.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // --- 2. 소비 분석 탭 ---
  Widget _buildSpendingTab() {
    int currentMonthSpending = _currentMonthSpending;
    int lastMonthSpending = _lastMonthSpending;
    int budgetAmount = _budgetAmount;

    // 만약 소비 비율 분모가 0이 되는 것을 방지
    double totalDiv = currentMonthSpending > 0 ? currentMonthSpending.toDouble() : 1.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이번달 소비 리포트 카드
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0.5,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('이번 달 소비 현황', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    '${NumberFormat('#,###').format(currentMonthSpending)} 원',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        lastMonthSpending >= currentMonthSpending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: lastMonthSpending >= currentMonthSpending ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        lastMonthSpending >= currentMonthSpending
                            ? '지난달 대비 ${NumberFormat('#,###').format(lastMonthSpending - currentMonthSpending)}원 덜 썼어요!'
                            : '지난달 대비 ${NumberFormat('#,###').format(currentMonthSpending - lastMonthSpending)}원 더 썼어요!',
                        style: TextStyle(
                          fontSize: 12,
                          color: lastMonthSpending >= currentMonthSpending ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 예산 대비 게이지
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('한 달 권장 예산', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(
                            '${math.min(100, ((currentMonthSpending / budgetAmount) * 100).toInt())}% 사용 (${NumberFormat('#,###').format(budgetAmount)}원 기준)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: math.min(1.0, currentMonthSpending / budgetAmount),
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            currentMonthSpending > budgetAmount ? Colors.redAccent : const Color(0xFF4F46E5),
                          ),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 소비 카테고리별 비중
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0.5,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('주요 지출 카테고리', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 20),
                  _buildCategoryBar('식비/카페', _foodSpending / totalDiv, Colors.orange, '${NumberFormat('#,###').format(_foodSpending)}원'),
                  const SizedBox(height: 16),
                  _buildCategoryBar('쇼핑/패션', _shoppingSpending / totalDiv, Colors.purple, '${NumberFormat('#,###').format(_shoppingSpending)}원'),
                  const SizedBox(height: 16),
                  _buildCategoryBar('교통/차량', _transportSpending / totalDiv, Colors.blue, '${NumberFormat('#,###').format(_transportSpending)}원'),
                  const SizedBox(height: 16),
                  _buildCategoryBar('기타/이체', _etcSpending / totalDiv, Colors.teal, '${NumberFormat('#,###').format(_etcSpending)}원'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 스마트 소비 챌린지 코너 (Interactive)
          const Text('지속 가능한 소비 챌린지', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          Text(
            '챌린지를 활성화하여 이번 달 충동 소비를 줄이고 리워드를 모아보세요!',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          _buildChallengeCard(
            icon: Icons.fastfood_rounded,
            color: Colors.orange,
            title: '식비/배달 줄이기 챌린지',
            subtitle: '목표: 한 달 30만원 이하 쓰기',
            isActive: _foodChallengeActive,
            progress: _foodChallengeActive ? math.min(1.0, _foodSpending / 300000) : 0.0,
            onChanged: (val) {
              setState(() {
                _foodChallengeActive = val;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildChallengeCard(
            icon: Icons.coffee_rounded,
            color: Colors.brown,
            title: '테이크아웃 커피 절약 챌린지',
            subtitle: '목표: 커피 비용 5만원 이하 쓰기',
            isActive: _coffeeChallengeActive,
            progress: _coffeeChallengeActive ? math.min(1.0, (_foodSpending * 0.15).toInt() / 50000) : 0.0,
            onChanged: (val) {
              setState(() {
                _coffeeChallengeActive = val;
              });
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(String category, double ratio, Color color, String amountText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(category, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
            Text(amountText, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('${(ratio * 100).toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildChallengeCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool isActive,
    required double progress,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? color.withOpacity(0.3) : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isActive,
                activeColor: color,
                onChanged: onChanged,
              ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('현재 도달율', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text(
                  '${(progress * 100).toInt()}% 사용중 (${progress > 0.8 ? "주의!" : "안정"})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: progress > 0.8 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(progress > 0.8 ? Colors.red : Colors.green),
              ),
            )
          ]
        ],
      ),
    );
  }
}

// --- Donut Chart CustomPainter ---
class DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  DonutChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    double total = values.fold(0, (sum, item) => sum + item);
    if (total == 0) return;

    double startAngle = -math.pi / 2;
    double strokeWidth = 14;
    double radius = (size.width - strokeWidth) / 2;
    Offset center = Offset(size.width / 2, size.height / 2);

    Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < values.length; i++) {
      double sweepAngle = (values[i] / total) * 2 * math.pi;
      paint.color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle - 0.06, // 약간의 구분 갭 적용
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.colors != colors;
  }
}
