import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LoanAdDetailScreen extends StatefulWidget {
  final String type; // 'credit' | 'mortgage' | 'deposit' | 'emergency'

  const LoanAdDetailScreen({super.key, required this.type});

  @override
  State<LoanAdDetailScreen> createState() => _LoanAdDetailScreenState();
}

class _LoanAdDetailScreenState extends State<LoanAdDetailScreen> {
  // 공통 사용자 데이터
  String _userName = '고객';
  String _userId = '';

  // 계산기 상태 변수
  // 1. 신용대출
  double _creditIncome = 5000; // 연소득 (만원)
  String _creditJob = '직장인'; // 직업군
  double _creditExistingLoan = 1000; // 기존대출 (만원)

  // 2. 주택담보대출
  double _housePrice = 50000; // 주택시세 (만원)
  double _ltvRatio = 60; // LTV 비율 (%)

  // 3. 전세자금대출
  double _depositAmount = 20000; // 전세 보증금 (만원)

  // 4. 비상금대출
  double _creditScore = 750; // 신용 점수

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
        setState(() {
          _userName = doc.data()?['name'] ?? '고객';
          _userId = userId;
        });
      }
    }
  }

  // --- 신용대출 계산 로직 ---
  Map<String, dynamic> _calculateCreditLoan() {
    double jobWeight = 1.8;
    if (_creditJob == '개인사업자') jobWeight = 1.2;
    if (_creditJob == '프리랜서') jobWeight = 0.8;
    if (_creditJob == '주부/무직') jobWeight = 0.2;

    double maxLimit = (_creditIncome * jobWeight) - _creditExistingLoan;
    if (maxLimit < 0) maxLimit = 0;
    if (maxLimit > 20000) maxLimit = 20000; // 최대 2억원 제한

    double rate = 3.5;
    if (_creditJob == '개인사업자') rate += 1.0;
    if (_creditJob == '프리랜서') rate += 1.8;
    if (_creditJob == '주부/무직') rate += 3.0;
    rate += (_creditExistingLoan / 5000) * 0.5; // 기존 대출에 따른 가산 금리
    if (rate > 12.0) rate = 12.0;

    return {
      'limit': maxLimit.toInt() * 10000,
      'rate': double.parse(rate.toStringAsFixed(2)),
    };
  }

  // --- 주택담보대출 계산 로직 ---
  Map<String, dynamic> _calculateMortgageLoan() {
    double limit = _housePrice * (_ltvRatio / 100);
    if (limit > 100000) limit = 100000; // 최대 10억원 제한

    double rate = 3.2 + (limit / 200000) + ((70 - _ltvRatio) * -0.01);
    if (rate < 3.0) rate = 3.0;

    return {
      'limit': limit.toInt() * 10000,
      'rate': double.parse(rate.toStringAsFixed(2)),
    };
  }

  // --- 전세자금대출 계산 로직 ---
  Map<String, dynamic> _calculateDepositLoan() {
    double limit = _depositAmount * 0.8;
    if (limit > 50000) limit = 50000; // 최대 5억원 제한

    double rate = 3.0 + (limit / 150000);
    return {
      'limit': limit.toInt() * 10000,
      'rate': double.parse(rate.toStringAsFixed(2)),
    };
  }

  // --- 비상금대출 계산 로직 ---
  Map<String, dynamic> _calculateEmergencyLoan() {
    int limit = 3000000; // 300만원 고정
    double rate = 4.5;
    if (_creditScore < 600) {
      rate = 9.5;
    } else if (_creditScore < 750) {
      rate = 7.2;
    } else if (_creditScore < 900) {
      rate = 5.5;
    } else {
      rate = 3.8;
    }
    return {
      'limit': limit,
      'rate': rate,
    };
  }

  // --- 상담 및 가입 안내 다이얼로그 호출 ---
  void _showConsultationDialog(BuildContext context, String title, int calculatedLimit, double calculatedRate, String description) {
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
                    Icon(Icons.info_outline_rounded, color: Colors.blue.shade600, size: 28),
                    const SizedBox(width: 8),
                    const Text(
                      '대출 신청 안내',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '선택하신 [$title] 상품은 보다 안전하고 꼼꼼한 대출 심사와 신용도 관리를 위해 비대면 즉시 승인 대신 전문 상담원 또는 영업점 창구를 통해 심사 및 가입을 도와드리고 있습니다.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
                ),
                const SizedBox(height: 20),
                
                // 설계 정보 요약 카드
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
                        '나의 모의 한도 정보',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          Text(
                            calculatedLimit > 0
                                ? '최대 ${NumberFormat('#,###').format(calculatedLimit)}원'
                                : '대출 불가 (한도 부족)',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('예상 설계 금리', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          Text(
                            '연 $calculatedRate%',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // 가입 안내 채널 리스트
                const Text(
                  '대출 상담 방법 선택',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                
                // 1. 전화 상담 연결
                _buildMethodCard(
                  icon: Icons.phone_in_talk_rounded,
                  iconColor: Colors.green,
                  title: '조이뱅크 대출 심사 고객센터 전화상담',
                  subtitle: '1588-5678 (평일 09:00 ~ 18:00)',
                  onTap: () {
                    Navigator.pop(context);
                    _showCallConnectionDialog(title);
                  },
                ),
                const SizedBox(height: 12),
                
                // 2. 간편 상담원 예약 신청
                _buildMethodCard(
                  icon: Icons.edit_calendar_rounded,
                  iconColor: Colors.purple,
                  title: '간편 대출 전화상담 예약',
                  subtitle: '대출 전담 상담원이 직접 신속히 연락을 드립니다.',
                  onTap: () {
                    Navigator.pop(context);
                    _handleConsultationRequest(context, title, calculatedLimit, calculatedRate, description);
                  },
                ),
                const SizedBox(height: 12),
                
                // 3. 은행 창구 방문 안내
                _buildMethodCard(
                  icon: Icons.storefront_rounded,
                  iconColor: Colors.orange,
                  title: '가까운 은행 창구 방문 (필수서류 지참)',
                  subtitle: '대기표 발행 후 위 설계 정보를 보여주시면 즉시 심사 개시',
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

  // --- 전화 상담 신청 처리 ---
  void _handleConsultationRequest(BuildContext context, String title, int calculatedLimit, double calculatedRate, String description) async {
    if (_userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보가 존재하지 않습니다.')),
      );
      return;
    }

    try {
      final now = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(now);
      final requestId = 'DL-${now.millisecondsSinceEpoch.toString().substring(5)}';

      // Firestore에 대출 상담 요청 저장
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('loan_consultations')
          .add({
        'requestId': requestId,
        'loanType': widget.type,
        'title': title,
        'limit': calculatedLimit,
        'rate': calculatedRate,
        'description': description,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // 알림 내역에도 저장
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('notifications')
          .add({
        'title': '대출 상담 신청 완료',
        'message': '[$title] 대출 사전설계 상담이 접수되었습니다. 담당 대출상담원이 빠르게 전화드리겠습니다.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // 성공 팝업 노출
      _showConsultationSuccessDialog(title, requestId, formattedDate, calculatedLimit, calculatedRate);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상담 신청 중 오류가 발생했습니다: $e')),
      );
    }
  }

  // --- 대출 상담 예약 성공 다이얼로그 ---
  void _showConsultationSuccessDialog(String title, String requestId, String date, int limit, double rate) {
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
                      color: Colors.purple.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_callback_rounded, size: 40, color: Colors.purple),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '상담 예약 완료!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_userName님의 대출 가입 문의 상담이 접수되었습니다.\n대출 전담 상담원이 곧 연락드릴 예정입니다.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  // 접수 확인 증서 스타일 카드
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
                        _buildReceiptRow('대출 상품', title),
                        const Divider(height: 16),
                        _buildReceiptRow('희망 설계한도', '${NumberFormat('#,###').format(limit)}원'),
                        const Divider(height: 16),
                        _buildReceiptRow('신청 연금리', '연 $rate%'),
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
                        Navigator.of(context).pop(); // 성공 팝업 닫기
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade600,
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
  void _showCallConnectionDialog(String loanTitle) {
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
                '[$loanTitle] 전문 대출 상담원에게 연결하고 있습니다.\n\n연결 전화번호: 1588-5678\n(평일 09:00 ~ 18:00)',
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
    final designCode = 'LN-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
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
                '가까운 조이뱅크 영업점 대출 창구를 방문하시면 세밀한 서류 심사 및 추가 한도 우대 조건으로 즉시 심사를 받으실 수 있습니다.',
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
                    const Text('나의 사전 모의설계 코드', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                    const SizedBox(height: 4),
                    Text(
                      designCode,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '대출 담당 창구 직원에게 위 설계 코드를 보여주시면 보다 빠르게 심사가 진행됩니다.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const BulletPointText('영업점 준비 서류: 신분증, 소득금액증명원, 재직증명서(또는 사업자등록증)'),
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

  @override
  Widget build(BuildContext context) {
    Color primaryColor;
    Color lightBgColor;
    String title;
    String subtitle;
    String heroText;
    String heroSub;
    IconData heroIcon;
    List<Map<String, dynamic>> benefits;

    if (widget.type == 'mortgage') {
      primaryColor = const Color(0xFF78350F);
      lightBgColor = const Color(0xFFFEF3C7);
      title = '주택 담보 대출';
      subtitle = '내 집 마련을 위한 첫걸음';
      heroText = '가장 합리적인 주택 대출!';
      heroSub = '최대 10억원, 최장 40년 만기 설계로 매달 납입 부담을 덜어주는 장기 대출 상품';
      heroIcon = Icons.home_work_rounded;
      benefits = [
        {
          'title': '든든한 최장 40년 상환',
          'desc': '상환 기간을 최장 40년까지 넉넉하게 설정하여 원리금 월 납입 부담을 극적으로 낮춰드려요.',
          'icon': Icons.calendar_month,
        },
        {
          'title': '금리 변동 리스크 방어',
          'desc': '고정금리와 변동금리 혼합형 설계로 금리 상승기에도 안심하고 안정적으로 상환 가능.',
          'icon': Icons.security,
        },
        {
          'title': '최대 LTV 70% 완화 보장',
          'desc': '정부 가이드라인에 맞춘 합리적 한도로 내 집 마련의 꿈을 실현하도록 돕습니다.',
          'icon': Icons.percent,
        }
      ];
    } else if (widget.type == 'deposit') {
      primaryColor = const Color(0xFF0D9488);
      lightBgColor = const Color(0xFFF0FDFA);
      title = '전세 자금 대출';
      subtitle = '보증금 걱정 없이 안심 이사';
      heroText = '보증금의 80% 든든하게!';
      heroSub = '부담 없는 이자율과 신속한 보증서 발급으로 편리하게 이사 준비를 마칠 수 있습니다.';
      heroIcon = Icons.house_siding_rounded;
      benefits = [
        {
          'title': '보증금 대비 80% 지원',
          'desc': '수도권 최대 5억원, 지방 최대 3억원까지 넉넉하게 보증금 한도를 지원해 드립니다.',
          'icon': Icons.payments_rounded,
        },
        {
          'title': '안심 전세금 반환 보증',
          'desc': '대출 실행과 함께 전세금 반환 보증보험 가입을 동시에 연계하여 소중한 전세금을 끝까지 지켜요.',
          'icon': Icons.verified_user_rounded,
        },
        {
          'title': '청년/신혼부부 추가 우대',
          'desc': '청년 가구 및 신혼부부 요건 충족 시 기본 금리에서 최대 연 0.3%p 추가 우대 금리 적용.',
          'icon': Icons.favorite,
        }
      ];
    } else if (widget.type == 'emergency') {
      primaryColor = const Color(0xFFEF4444);
      lightBgColor = const Color(0xFFFEF2F2);
      title = '포켓 비상금 대출';
      subtitle = '필요할 때 바로 꺼내쓰는 300만원';
      heroText = '서류 한 장 없이 1분 컷!';
      heroSub = '급하게 단기 자금이 필요할 때 마이너스 통장식으로 꺼내 쓰고 갚는 똑똑한 소액 비상금 대출';
      heroIcon = Icons.bolt_rounded;
      benefits = [
        {
          'title': '무서류 / 모바일 1초 조회',
          'desc': '직장 정보나 소득 증빙 서류 제출 없이 신용도 평가만으로 빠른 한도 조회가 완료됩니다.',
          'icon': Icons.offline_bolt_rounded,
        },
        {
          'title': '마이너스 통장식 운용',
          'desc': '한도를 약정해 두고 필요할 때만 인출하여 사용하며 이자는 사용한 기간과 금액만큼만 부과.',
          'icon': Icons.credit_card_rounded,
        },
        {
          'title': '중도상환 해약금 Zero',
          'desc': '대출 기간 중 언제든지 중도 상환을 해도 추가로 발생하는 수수료가 전혀 없습니다.',
          'icon': Icons.money_off_rounded,
        }
      ];
    } else {
      // credit
      primaryColor = const Color(0xFF8B5CF6);
      lightBgColor = const Color(0xFFF5F3FF);
      title = '맞춤 신용대출';
      subtitle = '직장인을 위한 스마트 신용한도';
      heroText = '쉽고 간편한 맞춤형 신용 대출';
      heroSub = '최대 2억원 한도까지, 최저 연 3%대 금리로 내 소득에 꼭 맞춘 자금 설계를 지원합니다.';
      heroIcon = Icons.person_pin_rounded;
      benefits = [
        {
          'title': '최대 2억원의 넉넉한 한도',
          'desc': '고객님의 신용 평점과 연소득 데이터를 분석하여 업계 최고 수준의 넉넉한 한도를 제공합니다.',
          'icon': Icons.monetization_on_rounded,
        },
        {
          'title': '간편 온라인 소득 스크래핑',
          'desc': '공인인증 절차를 통해 국민건강보험 및 국세청 서류가 자동으로 확인되어 서류 수기 제출이 불필요합니다.',
          'icon': Icons.cloud_done_rounded,
        },
        {
          'title': '우수 거래 고객 추가 금리 인하',
          'desc': '조이뱅크 급여 이체 내역 및 카드 사용 실적에 따라 우대금리 혜택이 최대 연 1.5%p 제공됩니다.',
          'icon': Icons.trending_down_rounded,
        }
      ];
    }

    // 모의 계산 결과 구하기
    int calculatedLimit = 0;
    double calculatedRate = 0.0;
    String calcDescription = '';

    if (widget.type == 'mortgage') {
      final res = _calculateMortgageLoan();
      calculatedLimit = res['limit'] as int;
      calculatedRate = res['rate'] as double;
      calcDescription = '주택 시세 ${NumberFormat('#,###').format(_housePrice.toInt())}만원 / LTV ${_ltvRatio.toInt()}% 기준 모의 설계';
    } else if (widget.type == 'deposit') {
      final res = _calculateDepositLoan();
      calculatedLimit = res['limit'] as int;
      calculatedRate = res['rate'] as double;
      calcDescription = '전세 보증금 ${NumberFormat('#,###').format(_depositAmount.toInt())}만원 대비 80% 대출 설계';
    } else if (widget.type == 'emergency') {
      final res = _calculateEmergencyLoan();
      calculatedLimit = res['limit'] as int;
      calculatedRate = res['rate'] as double;
      calcDescription = '모바일 포켓 신용 평점 대출 (신용 평점: ${_creditScore.toInt()}점) 기준';
    } else {
      final res = _calculateCreditLoan();
      calculatedLimit = res['limit'] as int;
      calculatedRate = res['rate'] as double;
      calcDescription = '연소득 ${NumberFormat('#,###').format(_creditIncome.toInt())}만원 / 기존 대출 ${NumberFormat('#,###').format(_creditExistingLoan.toInt())}만원 기준 ($_creditJob)';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 히어로 배너
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withOpacity(0.85)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        subtitle,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            heroText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(heroIcon, size: 72, color: Colors.white.withOpacity(0.35)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      heroSub,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. 가입 시뮬레이터 (대출 설계기)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '1초 맞춤 대출 한도 설계기',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '소득 및 조건 정보를 설정하여 예상 한도와 예상 금리를 가상으로 설계합니다.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: lightBgColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: primaryColor.withOpacity(0.15)),
                    ),
                    child: Column(
                      children: [
                        if (widget.type == 'mortgage') ...[
                          // 주택담보대출 설계기
                          _buildCalculatorRow(
                            label: '주택 시세 설정',
                            value: '${NumberFormat('#,###').format(_housePrice.toInt())} 만원',
                          ),
                          Slider(
                            value: _housePrice,
                            min: 5000,
                            max: 150000,
                            divisions: 29,
                            activeColor: primaryColor,
                            inactiveColor: primaryColor.withOpacity(0.2),
                            onChanged: (val) {
                              setState(() {
                                _housePrice = val;
                              });
                            },
                          ),
                          const Divider(height: 24),
                          _buildCalculatorRow(
                            label: 'LTV 비율 희망 한도',
                            value: '${_ltvRatio.toInt()} %',
                          ),
                          Slider(
                            value: _ltvRatio,
                            min: 40,
                            max: 70,
                            divisions: 6,
                            activeColor: primaryColor,
                            inactiveColor: primaryColor.withOpacity(0.2),
                            onChanged: (val) {
                              setState(() {
                                _ltvRatio = val;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildSimResultView(primaryColor, calculatedLimit, calculatedRate),
                        ] else if (widget.type == 'deposit') ...[
                          // 전세자금대출 설계기
                          _buildCalculatorRow(
                            label: '전세 보증금액 설정',
                            value: '${NumberFormat('#,###').format(_depositAmount.toInt())} 만원',
                          ),
                          Slider(
                            value: _depositAmount,
                            min: 3000,
                            max: 80000,
                            divisions: 77,
                            activeColor: primaryColor,
                            inactiveColor: primaryColor.withOpacity(0.2),
                            onChanged: (val) {
                              setState(() {
                                _depositAmount = val;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildSimResultView(primaryColor, calculatedLimit, calculatedRate),
                        ] else if (widget.type == 'emergency') ...[
                          // 비상금대출 설계기
                          _buildCalculatorRow(
                            label: '나의 대략적인 신용 평점',
                            value: '${_creditScore.toInt()} 점',
                          ),
                          Slider(
                            value: _creditScore,
                            min: 300,
                            max: 1000,
                            divisions: 70,
                            activeColor: primaryColor,
                            inactiveColor: primaryColor.withOpacity(0.2),
                            onChanged: (val) {
                              setState(() {
                                _creditScore = val;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildSimResultView(primaryColor, calculatedLimit, calculatedRate),
                        ] else ...[
                          // 신용대출 설계기
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('나의 직업군', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              Row(
                                children: ['직장인', '개인사업자', '프리랜서', '주부/무직'].map((job) {
                                  bool isSelected = _creditJob == job;
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: ChoiceChip(
                                      label: Text(job),
                                      selected: isSelected,
                                      selectedColor: primaryColor,
                                      labelStyle: TextStyle(
                                        color: isSelected ? Colors.white : Colors.black87,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      onSelected: (val) {
                                        if (val) {
                                          setState(() {
                                            _creditJob = job;
                                          });
                                        }
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _buildCalculatorRow(
                            label: '연소득 설정',
                            value: '${NumberFormat('#,###').format(_creditIncome.toInt())} 만원',
                          ),
                          Slider(
                            value: _creditIncome,
                            min: 1000,
                            max: 15000,
                            divisions: 28,
                            activeColor: primaryColor,
                            inactiveColor: primaryColor.withOpacity(0.2),
                            onChanged: (val) {
                              setState(() {
                                _creditIncome = val;
                              });
                            },
                          ),
                          const Divider(height: 16),
                          _buildCalculatorRow(
                            label: '기타 기대출 금액',
                            value: '${NumberFormat('#,###').format(_creditExistingLoan.toInt())} 만원',
                          ),
                          Slider(
                            value: _creditExistingLoan,
                            min: 0,
                            max: 10000,
                            divisions: 20,
                            activeColor: primaryColor,
                            inactiveColor: primaryColor.withOpacity(0.2),
                            onChanged: (val) {
                              setState(() {
                                _creditExistingLoan = val;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildSimResultView(primaryColor, calculatedLimit, calculatedRate),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. 주요 혜택 카드
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '주요 가입 혜택',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  ...benefits.map((b) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(b['icon'], color: primaryColor, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b['title'],
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  b['desc'],
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            // 4. 대출 가이드라인 주의 안내문구 추가
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('대출 유의사항 및 신용 평점 주의 안내', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                          const SizedBox(height: 6),
                          Text(
                            '• 과도한 대출은 개인 신용평점 하락의 원인이 될 수 있습니다.\n• 대출 실행 여부 및 한도, 이율은 고객님의 신용 상태와 소득 수준 등을 기반으로 영업점 창구의 최종 심사를 거쳐 최종 확정됩니다.\n• 상기 설계 결과는 가상의 모의 데이터이며 실제 대출 한도 및 이율과 상이할 수 있습니다.',
                            style: TextStyle(fontSize: 11, color: Colors.red.shade900, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                _showConsultationDialog(context, title, calculatedLimit, calculatedRate, calcDescription);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              child: const Text(
                '대출 상담 및 창구 안내',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 보조 위젯 ---
  Widget _buildCalculatorRow({required String label, required String value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildSimResultView(Color primaryColor, int limit, double rate) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('예상 맞춤 한도', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(
                limit > 0 ? '${NumberFormat('#,###').format(limit)} 원' : '대출 불가',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: limit > 0 ? primaryColor : Colors.red),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('예상 최저 금리', style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.bold)),
              Text(
                '연 $rate %',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
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
