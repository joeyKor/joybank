import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_screen.dart';
import 'login_screen.dart';
import 'pin_reset_screen.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  String _correctPin = '';
  bool _isLoading = true;
  int _incorrectPinAttempts = 0;
  static const int _maxIncorrectAttempts = 5;
  String _errorMessage = '';

  // 4열 키패드 아이템 (12개: 1행 4개, 2행 4개, 3행 4개)
  List<String> _keypadItems = [
    '1', '2', '3', '4',
    '조이', '5', '6', '조이',
    '7', '8', '9', '0',
  ];

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  void _loadPin() async {
    final prefs = await SharedPreferences.getInstance();
    _correctPin = prefs.getString('userPin') ?? '';
    setState(() {
      _isLoading = false;
    });
  }

  void _shuffleKeypad() {
    setState(() {
      List<String> digits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
      digits.shuffle();
      _keypadItems = [
        digits[0], digits[1], digits[2], digits[3],
        '조이', digits[4], digits[5], '조이',
        digits[6], digits[7], digits[8], digits[9],
      ];
    });
  }

  void _onNumberPress(String number) {
    if (_pin.length < 6) {
      setState(() {
        _pin += number;
      });

      if (_pin.length == 6) {
        _onSubmit();
      }
    }
  }

  void _onBackspacePress() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _onSubmit() async {
    if (_pin == _correctPin) {
      _incorrectPinAttempts = 0;
      _errorMessage = '';
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    } else {
      setState(() {
        _pin = '';
        _incorrectPinAttempts++;
        if (_incorrectPinAttempts < _maxIncorrectAttempts) {
          _errorMessage =
              'PIN이 틀렸습니다. ($_incorrectPinAttempts/$_maxIncorrectAttempts)';
        } else {
          _errorMessage = 'PIN 입력 횟수 초과. 로그아웃됩니다.';
        }
      });

      if (_incorrectPinAttempts >= _maxIncorrectAttempts) {
        _logout();
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F6F8),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF005BAC))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: SafeArea(
        child: Column(
          children: [
            // --- 상단 콘텐츠 영역 ---
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 50),
                      // 타이틀
                      const Text(
                        '간편비밀번호 로그인',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF191F28),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 36),
                      // 6자리 PIN 인디케이터 (원형 테두리 형태)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          final isFilled = index < _pin.length;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isFilled ? const Color(0xFF005BAC) : Colors.transparent,
                              border: Border.all(
                                color: isFilled ? const Color(0xFF005BAC) : const Color(0xFFB0BEC5),
                                width: 1.5,
                              ),
                            ),
                          );
                        }),
                      ),
                      if (_errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      const SizedBox(height: 36),
                      // 하단 보조 링크 (간편비밀번호 재설정)
                      Center(
                        child: InkWell(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PinResetScreen(),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: Text(
                              '간편비밀번호 재설정',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // --- 하단 4열 보안 키패드 영역 ---
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFEBEEF2),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 키패드 상단 방패 헤더
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    color: const Color(0xFFE3E7ED),
                    child: Row(
                      children: const [
                        Icon(Icons.shield_rounded, size: 17, color: Color(0xFF334155)),
                        SizedBox(width: 8),
                        Text(
                          '간편비밀번호 입력',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 4열 키패드 행들
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      children: [
                        // 1행: 1, 2, 3, 4
                        Row(
                          children: [
                            _buildKeypadCell(_keypadItems[0]),
                            _buildKeypadCell(_keypadItems[1]),
                            _buildKeypadCell(_keypadItems[2]),
                            _buildKeypadCell(_keypadItems[3]),
                          ],
                        ),
                        // 2행: 조이, 5, 6, 조이
                        Row(
                          children: [
                            _buildKeypadCell(_keypadItems[4]),
                            _buildKeypadCell(_keypadItems[5]),
                            _buildKeypadCell(_keypadItems[6]),
                            _buildKeypadCell(_keypadItems[7]),
                          ],
                        ),
                        // 3행: 7, 8, 9, 0
                        Row(
                          children: [
                            _buildKeypadCell(_keypadItems[8]),
                            _buildKeypadCell(_keypadItems[9]),
                            _buildKeypadCell(_keypadItems[10]),
                            _buildKeypadCell(_keypadItems[11]),
                          ],
                        ),
                        // 4행: ↻ (새로고침), 빈칸, 빈칸, ← (백스페이스)
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _shuffleKeypad,
                                borderRadius: BorderRadius.circular(12),
                                child: const SizedBox(
                                  height: 60,
                                  child: Center(
                                    child: Icon(
                                      Icons.refresh_rounded,
                                      size: 28,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Expanded(child: SizedBox(height: 60)),
                            const Expanded(child: SizedBox(height: 60)),
                            Expanded(
                              child: InkWell(
                                onTap: _onBackspacePress,
                                borderRadius: BorderRadius.circular(12),
                                child: const SizedBox(
                                  height: 60,
                                  child: Center(
                                    child: Icon(
                                      Icons.arrow_back_rounded,
                                      size: 28,
                                      color: Color(0xFF1E293B),
                                    ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadCell(String item) {
    final isBrandTag = item == '조이' || item == '콕' || item == 'JB';
    return Expanded(
      child: InkWell(
        onTap: isBrandTag ? null : () => _onNumberPress(item),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 60,
          child: Center(
            child: Text(
              item,
              style: TextStyle(
                fontSize: isBrandTag ? 15 : 26,
                fontWeight: isBrandTag ? FontWeight.bold : FontWeight.w600,
                color: isBrandTag ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

