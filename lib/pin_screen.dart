import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    _correctPin = prefs.getString('userPin') ?? ''; // SharedPreferences에서 PIN 가져오기
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

  void _onSubmit() async { // async 추가
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
          _errorMessage = 'PIN이 틀렸습니다. (${_incorrectPinAttempts}/$_maxIncorrectAttempts)';
        } else {
          _errorMessage = 'PIN 입력 횟수 초과. 로그아웃됩니다.';
        }
      });

      if (_incorrectPinAttempts >= _maxIncorrectAttempts) {
        // 5회 이상 틀렸을 경우 로그아웃 처리
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear(); // 모든 SharedPreferences 데이터 삭제 (로그아웃)
        // 짧은 지연 후 로그인 화면으로 이동하여 메시지가 보일 시간을 줍니다.
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    flex: 2, // Adjust flex to give keypad more space
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'PIN 번호를 입력하세요',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(6, (index) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index < _pin.length
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[300],
                              ),
                            );
                          }),
                        ),
                        if (_errorMessage.isNotEmpty) // 오류 메시지 표시
                          Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: Text(
                              _errorMessage,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(height: 30), // Add some space
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const PinResetScreen()),
                            );
                          },
                          child: Text(
                            'PIN 번호를 잊으셨나요?',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3, // Give more space to the keypad
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.3, // Adjust aspect ratio
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: 12,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        if (index < 9) {
                          return _buildNumberButton('${index + 1}');
                        } else if (index == 10) {
                          return _buildNumberButton('0');
                        } else if (index == 11) {
                          return _buildBackspaceButton();
                        }
                        // The 10th item (index 9) is an empty container
                        return Container();
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _onNumberPress(number),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return Material(
      color: Colors.grey[200],
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _onBackspacePress,
        child: const Center(
          child: Icon(
            Icons.backspace_outlined,
            size: 24,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }
}