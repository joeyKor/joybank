import 'package:flutter/material.dart';

class PinInputDialog extends StatefulWidget {
  final String title;
  final String message;
  final Function(String)? onPinSet; // 새 PIN 설정 시 호출될 콜백
  final bool isSettingPin; // PIN 설정 모드인지 여부

  const PinInputDialog({
    super.key,
    this.title = 'PIN 입력',
    this.message = '송금을 위해 PIN을 입력해주세요.',
    this.onPinSet,
    this.isSettingPin = false,
  });

  @override
  State<PinInputDialog> createState() => _PinInputDialogState();
}

class _PinInputDialogState extends State<PinInputDialog> {
  String _pin = '';
  static const int _pinLength = 6;

  String _firstPin = ''; // 첫 번째 입력된 PIN
  bool _isConfirmingPin = false; // 두 번째 PIN 입력 단계인지 여부

  void _onNumberTap(String number) {
    if (_pin.length < _pinLength) {
      setState(() {
        _pin += number;
      });
      
      if (_pin.length == _pinLength) {
        // 모든 PIN 입력 시 자동 확인 진행
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            _onConfirmTap();
          }
        });
      }
    }
  }

  void _onBackspaceTap() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _onConfirmTap() {
    if (widget.isSettingPin) {
      if (!_isConfirmingPin) {
        if (_pin.length == _pinLength) {
          setState(() {
            _firstPin = _pin;
            _pin = '';
            _isConfirmingPin = true;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN은 6자리여야 합니다.')),
          );
        }
      } else {
        if (_pin == _firstPin) {
          if (widget.onPinSet != null) {
            widget.onPinSet!(_pin);
          }
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN이 일치하지 않습니다. 다시 입력해주세요.')),
          );
          setState(() {
            _pin = '';
            _isConfirmingPin = false;
          });
        }
      }
    } else {
      Navigator.of(context).pop(_pin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    // 폴드 펼침 모드나 세로가 짧은 화면 대응
    final bool isCompact = screenHeight < 680;
    final bool isVeryCompact = screenHeight < 560;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            top: 12,
            left: isCompact ? 16 : 24,
            right: isCompact ? 16 : 24,
            bottom: mediaQuery.padding.bottom + (isCompact ? 12 : 24),
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: isCompact ? 12 : 20),
                Container(
                  padding: EdgeInsets.all(isCompact ? 8 : 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    color: Theme.of(context).primaryColor,
                    size: isCompact ? 24 : 32,
                  ),
                ),
                SizedBox(height: isCompact ? 10 : 16),
                Text(
                  widget.isSettingPin
                      ? (_isConfirmingPin ? 'PIN 확인' : '새 PIN 설정')
                      : widget.title,
                  style: TextStyle(
                    fontSize: isCompact ? 19 : 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.isSettingPin
                      ? (_isConfirmingPin ? '다시 한번 PIN을 입력해주세요.' : '새로운 6자리 PIN을 입력해주세요.')
                      : widget.message,
                  style: TextStyle(
                    fontSize: isCompact ? 13 : 14,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isCompact ? 14 : 24),
                // 동그라미 인디케이터
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pinLength, (index) {
                    final double dotSize = isCompact ? 14 : 16;
                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 8),
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
                SizedBox(height: isCompact ? 16 : 28),
                // 숫자 키패드 Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: isVeryCompact ? 2.0 : (isCompact ? 1.8 : 1.6),
                    mainAxisSpacing: isCompact ? 6 : 8,
                    crossAxisSpacing: isCompact ? 6 : 8,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    if (index < 9) {
                      return _buildKeypadButton('${index + 1}', isCompact);
                    } else if (index == 9) {
                      // 취소 버튼
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                          child: Center(
                            child: Text(
                              '취소',
                              style: TextStyle(
                                fontSize: isCompact ? 15 : 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      );
                    } else if (index == 10) {
                      return _buildKeypadButton('0', isCompact);
                    } else if (index == 11) {
                      // 지우기 버튼
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _onBackspaceTap,
                          child: Center(
                            child: Icon(
                              Icons.backspace_outlined,
                              size: isCompact ? 18 : 20,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String number, bool isCompact) {
    return Material(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onNumberTap(number),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              fontSize: isCompact ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}