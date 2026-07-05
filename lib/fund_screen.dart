import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FundScreen extends StatefulWidget {
  const FundScreen({super.key});

  @override
  State<FundScreen> createState() => _FundScreenState();
}

class _FundScreenState extends State<FundScreen> {
  String _userName = '고객';
  String _userId = '';
  bool _isLoading = true;
  String _selectedCategory = '전체';

  // 펀드 상품 데이터 리스트
  final List<Map<String, dynamic>> _funds = [
    {
      'id': 'fund_tech',
      'title': '조이 미국 빅테크 성장주 펀드',
      'category': '주식형',
      'risk': '초고위험',
      'riskColor': Colors.red,
      'return3m': '+12.5%',
      'return1y': '+38.2%',
      'manager': '조이글로벌자산운용',
      'desc': '애플, 마이크로소프트, 엔비디아 등 글로벌 혁신 기술 및 AI 메가트렌드를 선도하는 미국 빅테크 기업에 집중 투자합니다.',
    },
    {
      'id': 'fund_semicon',
      'title': '아시아 핵심 반도체 주식형 펀드',
      'category': '주식형',
      'risk': '고위험',
      'riskColor': Colors.orange,
      'return3m': '+8.7%',
      'return1y': '+28.4%',
      'manager': '조이셀렉트운용',
      'desc': '한국, 대만, 일본의 반도체 파운드리, 장비 및 설계 글로벌 리딩 기업에 분산 투자하여 성장성을 추구합니다.',
    },
    {
      'id': 'fund_esg',
      'title': '글로벌 친환경 ESG 혼합형 펀드',
      'category': '혼합형',
      'risk': '중위험',
      'riskColor': Colors.green,
      'return3m': '+4.2%',
      'return1y': '+12.8%',
      'manager': '조이안심자산운용',
      'desc': '환경(E), 사회(S), 지배구조(G)가 우수한 지속가능 기업 주식과 안정적인 우량 채권에 자산을 나누어 투자합니다.',
    },
    {
      'id': 'fund_bond',
      'title': '조이 국공채 안심 채권형 펀드',
      'category': '채권형',
      'risk': '저위험',
      'riskColor': Colors.blue,
      'return3m': '+1.1%',
      'return1y': '+4.6%',
      'manager': '조이안심자산운용',
      'desc': '대한민국 정부 및 공공기관이 발행한 국공채에 자산의 60% 이상 투자하여 예적금 금리 플러스 알파의 안정적 수익을 추구합니다.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';

    if (userId.isNotEmpty) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        _userName = doc.data()?['name'] ?? '고객';
      }

      setState(() {
        _userId = userId;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  int _calculateExpectedReturn(String returnStr, int amount) {
    final cleanStr = returnStr.replaceAll('+', '').replaceAll('%', '');
    final rate = double.tryParse(cleanStr) ?? 0.0;
    return (amount * (1 + rate / 100)).round();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFunds = _selectedCategory == '전체'
        ? _funds
        : _funds.where((f) => f['category'] == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('스마트 펀드몰', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeroBanner(),
                _buildCategoryFilter(),
                Expanded(
                  child: filteredFunds.isEmpty
                      ? const Center(child: Text('해당 카테고리의 펀드가 없습니다.'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                          itemCount: filteredFunds.length,
                          itemBuilder: (context, index) {
                            return _buildFundCard(filteredFunds[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEA580C), Color(0xFFF97316)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(Icons.trending_up_rounded, size: 90, color: Colors.white.withOpacity(0.2)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('초보자 추천 가이드', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              const Text(
                '소액으로 시작하는 글로벌 자산 투자',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '커피 한 잔 값(1만 원)부터 든든하게 시작하는 조이뱅크 간편 펀드 케어',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = ['전체', '주식형', '혼합형', '채권형'];
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              selectedColor: const Color(0xFFEA580C),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _selectedCategory = cat;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFundCard(Map<String, dynamic> fund) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showFundDetailModal(fund),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: fund['riskColor'].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      fund['risk'],
                      style: TextStyle(color: fund['riskColor'], fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    fund['manager'],
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                fund['title'],
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('최근 3개월 수익률', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        fund['return3m'],
                        style: const TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('1년 수익률', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        fund['return1y'],
                        style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 펀드 상세 설계 모달 ---
  void _showFundDetailModal(Map<String, dynamic> fund) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        int investmentAmount = 500000;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: fund['riskColor'].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            fund['risk'],
                            style: TextStyle(color: fund['riskColor'], fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          fund['category'],
                          style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      fund['title'],
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      fund['desc'],
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
                    ),
                    const SizedBox(height: 24),

                    // 성과 지표 카드
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildPerformanceColumn('3개월 수익률', fund['return3m'], Colors.red),
                          _buildPerformanceColumn('1년 수익률', fund['return1y'], Colors.black87),
                          _buildPerformanceColumn('운용사', fund['manager'], Colors.black87),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 모의 투자 가입 설계
                    const Text('모의 투자 설계 설정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('희망 가상 투자금을 설정하여 미래 수익을 미리 확인합니다.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [100000, 500000, 1000000].map((amt) {
                        bool isSelected = investmentAmount == amt;
                        return ChoiceChip(
                          label: Text('${NumberFormat('#,###').format(amt ~/ 10000)}만원'),
                          selected: isSelected,
                          selectedColor: const Color(0xFFEA580C),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                investmentAmount = amt;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    
                    // 예상 수익 시뮬레이션 뷰
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.shade100),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('1년 후 예상 평가액', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${NumberFormat('#,###').format(_calculateExpectedReturn(fund['return1y'], investmentAmount))}원',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '(최근 1년 수익률 ${fund['return1y']} 기준)',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 상담 및 가입 안내 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showConsultationDialog(context, fund['title'], investmentAmount, fund['return1y'], fund['risk']);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text(
                          '투자 상담 및 창구 안내',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPerformanceColumn(String label, String value, Color valColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: valColor, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --- 투자 가입 상담 안내 다이얼로그 ---
  void _showConsultationDialog(BuildContext context, String title, int investmentAmount, String return1y, String risk) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.orange.shade700, size: 28),
                    const SizedBox(width: 8),
                    const Text(
                      '펀드 가입 절차 안내',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '선택하신 [$title] 상품은 금융소비자보호법에 따라 고객님의 투자성향 분석(적합성 보고서 작성)이 필수적인 상품입니다. 안전하고 올바른 자산 배분을 위해 전문 상담원 전화 상담 또는 영업점 창구를 통해서 가입이 진행됩니다.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
                ),
                const SizedBox(height: 20),
                
                // 모의 설계 카드 요약
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '나의 모의 투자 설계 정보',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          Text(
                            '${NumberFormat('#,###').format(investmentAmount)}원',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('위험도 등급', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            risk,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // 가입 경로 리스트
                const Text(
                  '상담 신청 채널 선택',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                
                // 1. 전화 상담 연결
                _buildMethodCard(
                  icon: Icons.phone_in_talk_rounded,
                  iconColor: Colors.green,
                  title: '조이뱅크 펀드케어 고객센터 전화상담',
                  subtitle: '1588-9999 (평일 09:00 ~ 18:00)',
                  onTap: () {
                    Navigator.pop(context);
                    _showCallConnectionDialog(title);
                  },
                ),
                const SizedBox(height: 12),
                
                // 2. 간편 상담 전화 예약
                _buildMethodCard(
                  icon: Icons.edit_calendar_rounded,
                  iconColor: Colors.purple,
                  title: '간편 자산 분석 전화 예약',
                  subtitle: '투자전문 상담원이 직접 신속히 연락을 드립니다.',
                  onTap: () {
                    Navigator.pop(context);
                    _handleConsultationRequest(context, title, investmentAmount, return1y);
                  },
                ),
                const SizedBox(height: 12),
                
                // 3. 은행 창구 방문 안내
                _buildMethodCard(
                  icon: Icons.storefront_rounded,
                  iconColor: Colors.orange,
                  title: '가까운 은행 창구 방문 (적합성 진단)',
                  subtitle: '위 임시 설계 정보를 보여주시면 신속히 맞춤 펀드 심사 개시',
                  onTap: () {
                    Navigator.pop(context);
                    _showBranchVisitDialog();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMethodCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 전화 상담 예약 처리 ---
  void _handleConsultationRequest(BuildContext context, String title, int investmentAmount, String return1y) async {
    if (_userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보가 존재하지 않습니다.')),
      );
      return;
    }

    try {
      final now = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(now);
      final requestId = 'FD-${now.millisecondsSinceEpoch.toString().substring(5)}';

      // Firestore에 펀드 상담 요청 저장
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('fund_consultations')
          .add({
        'requestId': requestId,
        'title': title,
        'amount': investmentAmount,
        'return1y': return1y,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // 알림에도 등록
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('notifications')
          .add({
        'title': '펀드 상담 예약 완료',
        'message': '[$title] 상품 가입 적합성 분석 및 투자 상담 예약이 정상 접수되었습니다.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      _showConsultationSuccessDialog(title, requestId, formattedDate, investmentAmount);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상담 예약 중 오류가 발생했습니다: $e')),
      );
    }
  }

  // --- 펀드 상담 예약 성공 다이얼로그 ---
  void _showConsultationSuccessDialog(String title, String requestId, String date, int amount) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Success',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            content: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_callback_rounded, size: 40, color: Colors.orange),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '상담 예약 완료!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_userName님의 펀드 가입 문의 상담이 접수되었습니다.\n자산 관리 전담 상담원이 곧 연락드릴 예정입니다.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  // 접수 증서 스타일 카드
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildReceiptRow('신청자명', _userName),
                        const Divider(height: 16),
                        _buildReceiptRow('상담 펀드', title),
                        const Divider(height: 16),
                        _buildReceiptRow('설계 투자액', '${NumberFormat('#,###').format(amount)}원'),
                        const Divider(height: 16),
                        _buildReceiptRow('접수 번호', requestId),
                        const Divider(height: 16),
                        _buildReceiptRow('접수 일시', date),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text(
                        '확인',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --- 전화 연결 팝업 ---
  void _showCallConnectionDialog(String fundTitle) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text(
                '고객센터 연결 중',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                '[$fundTitle] 펀드케어 전문 상담원에게 연결하고 있습니다.\n\n연결 전화번호: 1588-9999\n(평일 09:00 ~ 18:00)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.5),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('연결 취소', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 은행 창구 방문 안내 팝업 ---
  void _showBranchVisitDialog() {
    final designCode = 'FD-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(Icons.storefront_rounded, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text('영업점 방문 안내', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '가까운 조이뱅크 영업점 대출/투자 금융 창구를 방문하시면 투자자 적합성 성향 진단 후 가입하실 수 있습니다.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('나의 임시 투자 설계 코드', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                    const SizedBox(height: 4),
                    Text(
                      designCode,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '창구 직원에게 위 설계 코드를 제시하시면 신속히 적합성 검사 후 가입 처리를 도와드립니다.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const BulletPointText('영업점 준비 서류: 신분증'),
              const BulletPointText('영업시간: 평일 09:00 ~ 16:00'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

class BulletPointText extends StatelessWidget {
  final String text;
  const BulletPointText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87))),
        ],
      ),
    );
  }
}