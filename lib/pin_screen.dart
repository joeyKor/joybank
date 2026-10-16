import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_screen.dart';
import 'login_screen.dart'; // Import LoginScreen
import 'pin_reset_screen.dart'; // Import PinResetScreen

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  String _correctPin = '';
  bool _isLoading = true;
  int _incorrectPinAttempts = 0; // 틀린 PIN 시도 횟수
  static const int _maxIncorrectAttempts = 5; // 최대 허용 횟수
  String _errorMessage = ''; // 화면에 표시할 오류 메시지

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  void _loadPin() async {
    final prefs = await SharedPreferences.getInstance();
    _correctPin =
        prefs.getString('userPin') ?? ''; // SharedPreferences에서 PIN 가져오기
    setState(() {
      _isLoading = false;
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
    // async 추가
    if (_pin == _correctPin) {
      _incorrectPinAttempts = 0; // 성공 시 시도 횟수 초기화
      _errorMessage = ''; // 오류 메시지 초기화
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
        // 5회 이상 틀렸을 경우 로그아웃 처리
        _logout();
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // 모든 SharedPreferences 데이터 삭제
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false, // 모든 이전 라우트 제거
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            // 폴드 펼침 모드나 세로 길이가 짧은 화면 감지 (650dp 미만)
            final bool isCompact = availableHeight < 650;
            final bool isVeryCompact = availableHeight < 550;

            final double titleFontSize = isVeryCompact ? 18 : (isCompact ? 20 : 24);
            final double dotSize = isVeryCompact ? 16 : (isCompact ? 18 : 22);
            final double dotMargin = isVeryCompact ? 6 : (isCompact ? 8 : 10);
            final double keypadPadding = isVeryCompact ? 16 : (isCompact ? 24 : 36);
            final double keypadSpacing = isVeryCompact ? 6 : (isCompact ? 8 : 12);
            // 가로 대비 세로 높이 비율: 컴팩트 화면일수록 가로로 넓적하게 만들어 세로 공간 절약
            final double childAspectRatio = isVeryCompact ? 1.75 : (isCompact ? 1.55 : 1.35);

            return Center(
              child: ConstrainedBox(
                // 대화면/폴드 펼침 모드에서도 키패드가 무한정 커지지 않도록 최대 가로폭 제한
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: availableHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: isCompact ? 12 : 24,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 상단 헤더 및 안내 영역
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(height: isCompact ? 8 : 20),
                                Text(
                                  'PIN 번호를 입력하세요',
                                  style: TextStyle(
                                    fontSize: titleFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: isCompact ? 12 : 20),
                                // 6자리 PIN 인디케이터
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(6, (index) {
                                    return Container(
                                      margin: EdgeInsets.symmetric(
                                        horizontal: dotMargin,
                                      ),
                                      width: dotSize,
                                      height: dotSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: index < _pin.length
                                            ? Theme.of(context).primaryColor
                                            : Colors.grey[300],
                                      ),
                                    );
                                  }),
                                ),
                                if (_errorMessage.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(top: isCompact ? 6.0 : 10.0),
                                    child: Text(
                                      _errorMessage,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: isCompact ? 13 : 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                SizedBox(height: isCompact ? 10 : 18),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const PinResetScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'PIN 번호를 잊으셨나요?',
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontSize: isCompact ? 14 : 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(height: isCompact ? 4 : 8),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: _logout,
                                  child: Text(
                                    '로그아웃',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: isCompact ? 14 : 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // 하단 숫자 키패드 Grid 영역
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: keypadPadding,
                                vertical: isCompact ? 8 : 16,
                              ),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: childAspectRatio,
                                  mainAxisSpacing: keypadSpacing,
                                  crossAxisSpacing: keypadSpacing,
                                ),
                                itemCount: 12,
                                itemBuilder: (context, index) {
                                  if (index < 9) {
                                    return _buildNumberButton('${index + 1}', isCompact);
                                  } else if (index == 10) {
                                    return _buildNumberButton('0', isCompact);
                                  } else if (index == 11) {
                                    return _buildBackspaceButton(isCompact);
                                  }
                                  return const SizedBox();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number, bool isCompact) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
        child: InkWell(
          borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
          onTap: () => _onNumberPress(number),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: isCompact ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton(bool isCompact) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
        child: InkWell(
          borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
          onTap: _onBackspacePress,
          child: Center(
            child: Icon(
              Icons.backspace_outlined,
              size: isCompact ? 20 : 24,
              color: Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}
