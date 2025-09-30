import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final TextEditingController _pinController = TextEditingController();
  static const int _pinLength = 6;

  String _firstPin = ''; // 첫 번째 입력된 PIN
  bool _isConfirmingPin = false; // 두 번째 PIN 입력 단계인지 여부

  void _onNumberTap(String number) {
    if (_pinController.text.length < _pinLength) {
      _pinController.text += number;
    }
  }

  void _onBackspaceTap() {
    if (_pinController.text.isNotEmpty) {
      _pinController.text =
          _pinController.text.substring(0, _pinController.text.length - 1);
    }
  }

  void _onConfirmTap() {
    if (widget.isSettingPin) {
      if (!_isConfirmingPin) {
        // 첫 번째 PIN 입력 완료
        if (_pinController.text.length == _pinLength) {
          setState(() {
            _firstPin = _pinController.text;
            _pinController.clear();
            _isConfirmingPin = true;
          });
        } else {
          // PIN 길이가 6자리가 아닐 경우 에러 처리 (예: 스낵바)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN은 6자리여야 합니다.')),
          );
        }
      } else {
        // 두 번째 PIN 입력 완료
        if (_pinController.text == _firstPin) {
          if (widget.onPinSet != null) {
            widget.onPinSet!(_pinController.text);
          }
          Navigator.of(context).pop(); // 다이얼로그 닫기
        } else {
          // PIN 불일치 시 에러 처리
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN이 일치하지 않습니다. 다시 입력해주세요.')),
          );
          setState(() {
            _pinController.clear();
            _isConfirmingPin = false;
          });
        }
      }
    } else {
      Navigator.of(context).pop(_pinController.text);
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
          widget.isSettingPin
              ? (_isConfirmingPin ? 'PIN 확인' : '새 PIN 설정')
              : widget.title,
          textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Text(
                widget.isSettingPin
                    ? (_isConfirmingPin ? '다시 한번 PIN을 입력해주세요.' : '새로운 6자리 PIN을 입력해주세요.')
                    : widget.message,
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextField(
              controller: _pinController,
              decoration: const InputDecoration(labelText: 'PIN'),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
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
          onPressed: _onConfirmTap,
        ),
      ],
    );
  }
}