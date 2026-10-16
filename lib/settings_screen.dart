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

  // --- 버전 정보 히스토리 팝업 다이얼로그 ---
  void _showVersionHistoryDialog(BuildContext context) {
    final List<Map<String, dynamic>> versionHistory = [
      {
        'version': 'ver 2.1.0',
        'date': '2026.10.17',
        'isLatest': true,
        'changes': [
          '메인 홈 화면 모던 핀테크 스타일 전면 개편 (잔액 숨김 및 퀵 액션)',
          '조이페이 바코드/QR 결제 화면 및 상태 영수증 디자인 리뉴얼',
          '간편비밀번호(PIN) 및 로그인 보안 키패드 디자인 개편',
          '거래내역 화면 일시 상세 표기 및 입/출금 레이아웃 고도화',
          '가맹점 결제(PAYMENT) 데이터 분류 및 송금 프로세스 안정성 강화',
        ],
      },
      {
        'version': 'ver 2.0.0',
        'date': '2026.09.24',
        'isLatest': false,
        'changes': [
          '거래내역 화면 카카오뱅크 스타일 전면 개편',
          '시원한 대형 계좌 잔액 및 복사 가능한 계좌번호 배지 적용',
          '실시간 거래 검색 및 다차원 정렬/필터(기간, 거래구분, 정렬순) 도입',
          '각 거래 항목별 개별 일자(MM.dd) 및 타임스탬프 상세 표기',
          '하단 원터치 빠른 이체 액션 바 편의성 증대',
        ],
      },
      {
        'version': 'ver 1.0.0',
        'date': '2026.08.01',
        'isLatest': false,
        'changes': [
          '조이뱅크 모바일 뱅킹 서비스 공식 런칭',
          '계좌 개설, 잔액 조회 및 실시간 송금 기능 지원',
          '알림 설정 및 자산 케어 / 금융 상품 안내 서비스 연동',
        ],
      },
    ];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단 헤더: 타이틀 & 닫기 아이콘
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.update_rounded,
                              color: Color(0xFF2563EB),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            '버전별 업데이트 내역',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF191F28),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF8B95A1)),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // 버전 목록 스크롤 영역
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: versionHistory.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final item = versionHistory[index];
                        final isLatest = item['isLatest'] as bool;
                        final changes = item['changes'] as List<String>;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isLatest ? const Color(0xFFF8FAFC) : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isLatest ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
                              width: isLatest ? 1.4 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 버전 태그 및 날짜
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        item['version'] as String,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: isLatest
                                              ? const Color(0xFF1D4ED8)
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                      if (isLatest) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            '최신',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    item['date'] as String,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              const SizedBox(height: 10),
                              // 업데이트 항목 리스트
                              ...changes.map((change) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '• ',
                                          style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            change,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              height: 1.35,
                                              color: Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 확인 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFEB00),
                        foregroundColor: const Color(0xFF191F28),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '확인',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('앱 정보'),
              subtitle: const Text('ver 2.1.0 (최신 버전)'),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () => _showVersionHistoryDialog(context),
            ),
          ),
          const Divider(),
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
