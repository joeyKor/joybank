import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'pin_input_dialog.dart';

class InsuranceAdDetailScreen extends StatefulWidget {
  final String type; // 'medical' | 'car' | 'travel'

  const InsuranceAdDetailScreen({super.key, required this.type});

  @override
  State<InsuranceAdDetailScreen> createState() => _InsuranceAdDetailScreenState();
}

class _InsuranceAdDetailScreenState extends State<InsuranceAdDetailScreen> {
  // 공통 사용자 데이터
  String _userName = '고객';
  String _userId = '';
  String _userPin = '';

  // 계산기 상태 변수
  // 1. 실손의료비
  double _medicalAge = 30;
  String _medicalGender = '남성';

  // 2. 자동차
  double _carMileage = 8000;

  // 3. 여행자
  String _travelRegion = '아시아';
  double _travelDays = 5;
  double _travelCount = 1;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';
    final userPin = prefs.getString('userPin') ?? '';

    if (userId.isNotEmpty) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        setState(() {
          _userName = doc.data()?['name'] ?? '고객';
          _userId = userId;
          _userPin = userPin;
        });
      }
    }
  }

  // --- 실손의료비 계산 로직 ---
  int _calculateMedicalPremium() {
    int base = 12000;
    // 성별 가중치
    if (_medicalGender == '남성') base += 1500;
    if (_medicalGender == '여성') base += 800;

    // 나이 가중치
    if (_medicalAge < 30) {
      base = (base * 0.9).round();
    } else if (_medicalAge < 40) {
      base = (base * 1.2).round();
    } else if (_medicalAge < 50) {
      base = (base * 1.7).round();
    } else if (_medicalAge < 60) {
      base = (base * 2.5).round();
    } else {
      base = (base * 3.6).round();
    }
    return base;
  }

  // --- 자동차 보험 환급금 계산 로직 ---
  Map<String, dynamic> _calculateCarDiscount() {
    int basePremium = 780000;
    double discountRatio = 0.0;

    if (_carMileage <= 3000) {
      discountRatio = 0.35;
    } else if (_carMileage <= 5000) {
      discountRatio = 0.28;
    } else if (_carMileage <= 7000) {
      discountRatio = 0.20;
    } else if (_carMileage <= 10000) {
      discountRatio = 0.12;
    } else if (_carMileage <= 12000) {
      discountRatio = 0.06;
    } else {
      discountRatio = 0.01;
    }

    int refundAmount = (basePremium * discountRatio).round();
    return {
      'discountRatio': (discountRatio * 100).round(),
      'refundAmount': refundAmount,
      'finalPremium': basePremium - refundAmount,
    };
  }

  // --- 여행자 보험 계산 로직 ---
  int _calculateTravelPremium() {
    int pricePerDay = 1500;
    if (_travelRegion == '유럽') pricePerDay = 2500;
    if (_travelRegion == '미주') pricePerDay = 3000;
    if (_travelRegion == '기타') pricePerDay = 2000;

    double total = _travelDays * pricePerDay * _travelCount;
    // 동반 가입 할인 (2명 이상 시 10% 할인)
    if (_travelCount > 1) {
      total = total * 0.9;
    }
    return total.round();
  }

  // --- 가입 및 상담 안내 다이얼로그 호출 ---
  void _showConsultationDialog(BuildContext context, String title, int calculatedAmount, String description) {
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
                      '보험 가입 안내',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '선택하신 [$title] 상품은 보다 안전하고 든든한 맞춤 설계를 위해 비대면 직접 가입 대신 전문 상담원 또는 영업점 창구를 통해 가입을 도와드리고 있습니다.',
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
                        '나의 모의 설계 정보',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          Text(
                            widget.type == 'car'
                                ? '예상 연 ${NumberFormat('#,###').format(calculatedAmount)}원'
                                : '예상 월 ${NumberFormat('#,###').format(calculatedAmount)}원',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
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
                  '가입 방법 선택',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                
                // 1. 전화 상담 연결
                _buildMethodCard(
                  icon: Icons.phone_in_talk_rounded,
                  iconColor: Colors.green,
                  title: '조이뱅크 보험 고객센터 전화상담',
                  subtitle: '1588-1234 (평일 09:00 ~ 18:00)',
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
                  title: '간편 상담 전화 예약',
                  subtitle: '상담원이 직접 연락을 드립니다.',
                  onTap: () {
                    Navigator.pop(context);
                    _handleConsultationRequest(context, title, calculatedAmount, description);
                  },
                ),
                const SizedBox(height: 12),
                
                // 3. 은행 창구 방문 안내
                _buildMethodCard(
                  icon: Icons.storefront_rounded,
                  iconColor: Colors.orange,
                  title: '가까운 은행 창구 방문',
                  subtitle: '영업점 방문 시 설계 내역을 보여주시면 즉시 가입 가능',
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
  void _handleConsultationRequest(BuildContext context, String title, int calculatedAmount, String description) async {
    if (_userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보가 존재하지 않습니다.')),
      );
      return;
    }

    try {
      final now = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(now);
      final requestId = 'REQ-${now.millisecondsSinceEpoch.toString().substring(5)}';

      // Firestore에 상담 요청 저장
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('consultations')
          .add({
        'requestId': requestId,
        'insuranceType': widget.type,
        'title': title,
        'premium': calculatedAmount,
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
        'title': '상담 신청 완료',
        'message': '[$title] 가입 상담 예약이 정상적으로 신청되었습니다. 빠른 시일 내에 연락드리겠습니다.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // 성공 팝업 노출
      _showConsultationSuccessDialog(title, requestId, formattedDate);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상담 신청 중 오류가 발생했습니다: $e')),
      );
    }
  }

  // --- 상담 예약 성공 다이얼로그 ---
  void _showConsultationSuccessDialog(String title, String requestId, String date) {
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
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_callback_rounded, size: 40, color: Colors.blue),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '상담 예약 완료!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_userName님의 가입 문의 상담이 접수되었습니다.\n전문 상담원이 곧 연락드릴 예정입니다.',
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
                        _buildReceiptRow('상담 상품', title),
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
                        backgroundColor: Colors.blue.shade600,
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

  // --- 전화 연결 팝업 ---
  void _showCallConnectionDialog(String insuranceTitle) {
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
                '[$insuranceTitle] 전문 상담원에게 연결하고 있습니다.\n\n연결 전화번호: 1588-1234\n(평일 09:00 ~ 18:00)',
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
    final designCode = 'JB-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
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
                '가까운 조이뱅크 영업점 창구를 방문하시면 맞춤 상담 후 바로 가입하실 수 있습니다.',
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
                    const Text('나의 임시 설계 번호', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                    const SizedBox(height: 4),
                    Text(
                      designCode,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '창구 직원에게 위 설계 번호를 제시해주시면 신속한 가입 안내를 도와드립니다.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const BulletPointText('준비물: 신분증 (주민등록증, 운전면허증 등)'),
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

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 상품 타입에 따른 리소스 정의
    Color primaryColor;
    Color lightBgColor;
    String title;
    String subtitle;
    String heroText;
    String heroSub;
    IconData heroIcon;
    List<Map<String, dynamic>> benefits;

    if (widget.type == 'car') {
      primaryColor = const Color(0xFF10B981);
      lightBgColor = const Color(0xFFECFDF5);
      title = '다이렉트 자동차 보험';
      subtitle = '안전 운전을 위한 필수 선택';
      heroText = '갑작스러운 사고에도 든든하게!';
      heroSub = '마일리지 특약과 안전운전 할인으로 실속 있게 설계하는 자동차 필수 가드';
      heroIcon = Icons.directions_car_filled_rounded;
      benefits = [
        {
          'title': '최대 35% 마일리지 환급',
          'desc': '연간 적게 타면 주행거리에 따라 납입한 보험료를 통장으로 즉시 돌려드려요.',
          'icon': Icons.card_giftcard,
        },
        {
          'title': '365일 24시간 긴급출동',
          'desc': '전국 어디서나 배터리 방전, 타이어 펑크 등 고장 사고 시 평균 15분 내 현장 지원.',
          'icon': Icons.bolt,
        },
        {
          'title': '커넥티드카 12% 특약 할인',
          'desc': 'T맵 안전운전 점수가 기준치 이상이거나 커넥티드 장착 차량일 시 매력적인 추가 우대.',
          'icon': Icons.speed,
        }
      ];
    } else if (widget.type == 'travel') {
      primaryColor = const Color(0xFFF97316);
      lightBgColor = const Color(0xFFFFF7ED);
      title = '안심 여행자 보험';
      subtitle = '전 세계 어디서든 든든하게';
      heroText = '설레는 여행길, 걱정은 비우고!';
      heroSub = '단 1분 가입으로 해외 및 국내 어디서나 상해, 물품 분실로부터 보호받으세요.';
      heroIcon = Icons.flight_takeoff_rounded;
      benefits = [
        {
          'title': '휴대품 파손/도난 100만 보장',
          'desc': '고가의 스마트폰, 카메라 파손이나 도난 사고 시 든든하게 손해를 보전해 줍니다.',
          'icon': Icons.screenshot_monitor,
        },
        {
          'title': '해외 의료비 최대 5천만',
          'desc': '해외 현지 병원에서 급성 질환 치료 시 비싼 의료비 걱정 없이 집중 치료 지원.',
          'icon': Icons.healing_rounded,
        },
        {
          'title': '항공기 지연 / 수하물 지연',
          'desc': '기상 악화로 비행기가 지연되거나 짐이 늦게 나올 때 발생하는 필수 경비 지원.',
          'icon': Icons.work_history_rounded,
        }
      ];
    } else {
      // medical (기본)
      primaryColor = const Color(0xFF3B82F6);
      lightBgColor = const Color(0xFFEFF6FF);
      title = '실손 의료비 보험';
      subtitle = '병원비 걱정, 이젠 그만!';
      heroText = '아플 때 가장 먼저 생각나는 안심!';
      heroSub = '사소한 감기부터 입원, 정밀 검사까지 내가 지출한 병원비를 든든히 돌려받으세요.';
      heroIcon = Icons.local_hospital_rounded;
      benefits = [
        {
          'title': '입원 / 통원비 든든 보장',
          'desc': '국민건강보험 비보장 항목까지 급여 80%, 비급여 70% 수준으로 넉넉하게 돌려드려요.',
          'icon': Icons.assignment_turned_in_rounded,
        },
        {
          'title': '3대 비급여 특약 완벽 지원',
          'desc': '도수/체외충격파 치료, 주사제 공급 및 비급여 MRI 검사 비용까지 걱정 없이 보장.',
          'icon': Icons.health_and_safety_rounded,
        },
        {
          'title': '모바일 간편 사진 청구',
          'desc': '진료 후 영수증과 영수필증 사진만 올리면 평균 1영업일 이내 보험금 신속 지급.',
          'icon': Icons.send_to_mobile_rounded,
        }
      ];
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
            // 1. 히어로 배너 (Hero Banner with Animation)
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

            // 2. 가입 시뮬레이터 (Interactive Calculator Section)
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
                        '1초 보험료 계산기',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '정보를 설정하면 가상으로 즉시 보험료를 설계합니다.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),

                  // 계산기 위젯 동적 로드
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
                        if (widget.type == 'car') ...[
                          // 자동차 보험 계산기 설정
                          _buildCalculatorRow(
                            label: '연간 주행거리',
                            value: '${NumberFormat('#,###').format(_carMileage.toInt())} km',
                          ),
                          Slider(
                            value: _carMileage,
                            min: 2000,
                            max: 15000,
                            divisions: 26,
                            activeColor: primaryColor,
                            inactiveColor: primaryColor.withOpacity(0.2),
                            onChanged: (val) {
                              setState(() {
                                _carMileage = val;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildCarSimResultView(primaryColor),
                        ] else if (widget.type == 'travel') ...[
                          // 여행자 보험 계산기 설정
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('여행 국가', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              Row(
                                children: ['아시아', '유럽', '미주', '기타'].map((region) {
                                  bool isSelected = _travelRegion == region;
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: ChoiceChip(
                                      label: Text(region),
                                      selected: isSelected,
                                      selectedColor: primaryColor,
                                      labelStyle: TextStyle(
                                        color: isSelected ? Colors.white : Colors.black87,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      onSelected: (val) {
                                        if (val) {
                                          setState(() {
                                            _travelRegion = region;
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
                            label: '여행 기간',
                            value: '${_travelDays.toInt()}일간',
                          ),
                          Slider(
                            value: _travelDays,
                            min: 1,
                            max: 30,
                            divisions: 29,
                            activeColor: primaryColor,
                            inactiveColor: primaryColor.withOpacity(0.2),
                            onChanged: (val) {
                              setState(() {
                                _travelDays = val;
                              });
                            },
                          ),
                          const Divider(height: 16),
                          _buildCalculatorRow(
                            label: '동반 여행자',
                            value: '${_travelCount.toInt()}명',
                          ),
                          Slider(
                            value: _travelCount,
                            min: 1,
                            max: 5,
                            divisions: 4,
                            activeColor: primaryColor,
                            inactiveColor: primaryColor.withOpacity(0.2),
                            onChanged: (val) {
                              setState(() {
                                _travelCount = val;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildTravelSimResultView(primaryColor),
                        ] else ...[
                          // 실손의료비 계산기 설정
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('성별', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              Row(
                                children: ['남성', '여성'].map((gender) {
                                  bool isSelected = _medicalGender == gender;
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: ChoiceChip(
                                      label: Text(gender),
                                      selected: isSelected,
                                      selectedColor: primaryColor,
                                      labelStyle: TextStyle(
                                        color: isSelected ? Colors.white : Colors.black87,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      onSelected: (val) {
                                        if (val) {
                                          setState(() {
                                            _medicalGender = gender;
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
                            label: '연령 설정',
                            value: '만 ${_medicalAge.toInt()}세',
                          ),
                          Slider(
                            value: _medicalAge,
                            min: 20,
                            max: 70,
                            divisions: 50,
                            activeColor: primaryColor,
                            inactiveColor: primaryColor.withOpacity(0.2),
                            onChanged: (val) {
                              setState(() {
                                _medicalAge = val;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildMedicalSimResultView(primaryColor),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. 주요 혜택 카드 (Benefits Cards)
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

            // 4. 고객 만족도 후기 (Testimonial Card)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey.shade900, Colors.grey.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '고객 후기 리포트',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: const [
                            Icon(Icons.star, color: Colors.amber, size: 18),
                            SizedBox(width: 4),
                            Text(
                              '4.9 / 5.0',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.type == 'car'
                          ? '"기존 오프라인 보험 대비 주행거리 환급으로 약 20만원 환급받았어요. 절차가 정말 스마트합니다."'
                          : widget.type == 'travel'
                              ? '"비행기 결항 때문에 고생했는데 앱으로 증빙 올렸더니 당일 입금되었어요! 무조건 가입 추천!"'
                              : '"번거로운 보험 청구 서류가 모바일 사진 제출로 10초 만에 끝나서 감격했습니다. 강력 추천해요."',
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.type == 'car'
                          ? '김*우 (30대, 운전경력 5년)'
                          : widget.type == 'travel'
                              ? '이*주 (20대, 해외 배낭여행객)'
                              : '박*현 (40대, 자녀를 둔 가장)',
                      style: TextStyle(color: primaryColor.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 100), // 가입 버튼 여백
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
                // CTA 가입 및 상담 안내 처리
                if (widget.type == 'car') {
                  final result = _calculateCarDiscount();
                  final description = '마일리지 특약형 (주행거리 ${_carMileage.toInt()}km 기준)';
                  _showConsultationDialog(context, title, result['finalPremium'] as int, description);
                } else if (widget.type == 'travel') {
                  final premium = _calculateTravelPremium();
                  final description = '여행기간 ${_travelDays.toInt()}일 / 동반 ${_travelCount.toInt()}인 패키지';
                  _showConsultationDialog(context, title, premium, description);
                } else {
                  final premium = _calculateMedicalPremium();
                  final description = '만 ${_medicalAge.toInt()}세 / $_medicalGender 보장';
                  _showConsultationDialog(context, title, premium, description);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              child: const Text(
                '가입 상담 및 창구 안내',
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

  Widget _buildMedicalSimResultView(Color primaryColor) {
    int premium = _calculateMedicalPremium();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('월 예상 납입 보험료', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(
            '${NumberFormat('#,###').format(premium)} 원',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildCarSimResultView(Color primaryColor) {
    final result = _calculateCarDiscount();
    int refund = result['refundAmount'] as int;
    int discountRatio = result['discountRatio'] as int;
    int finalPrem = result['finalPremium'] as int;

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
              Text('환급 혜택 비율 ($discountRatio% 할인)', style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(
                '${NumberFormat('#,###').format(refund)} 원',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor),
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
              const Text('최종 예상 연간 보험료', style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.bold)),
              Text(
                '${NumberFormat('#,###').format(finalPrem)} 원',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTravelSimResultView(Color primaryColor) {
    int total = _calculateTravelPremium();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('예상 총 보험료 ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
              if (_travelCount > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('10% 동반할인', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          Text(
            '${NumberFormat('#,###').format(total)} 원',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
          ),
        ],
      ),
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
