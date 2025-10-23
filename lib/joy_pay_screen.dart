
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JoyPayScreen extends StatefulWidget {
  const JoyPayScreen({super.key});

  @override
  _JoyPayScreenState createState() => _JoyPayScreenState();
}

class _JoyPayScreenState extends State<JoyPayScreen> {
  String? _encryptedAccountNumber;
  int? _balance;
  Timer? _timer;
  int _countdown = 30;
  bool _showQr = true;

  @override
  void initState() {
    super.initState();
    _loadAccountDataAndGenerateQr();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _loadAccountDataAndGenerateQr() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null) {
      _showErrorDialog('사용자 ID를 찾을 수 없습니다. 다시 로그인해주세요.');
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .doc('main')
          .get();

      if (!doc.exists || doc.data() == null) {
        _showErrorDialog('계정 정보를 찾을 수 없습니다. 계정을 확인해주세요.');
        return;
      }

      final data = doc.data()!;
      final accountNumber = data['accountNumber'];
      final balance = (data['balance'] as num?)?.toInt();

      if (accountNumber == null) {
        _showErrorDialog('계좌 번호를 찾을 수 없습니다. 계정 설정을 확인해주세요.');
        return;
      }

      setState(() {
        _encryptedAccountNumber = _simpleEncrypt(accountNumber);
        _balance = balance;
        _showQr = true;
      });
      _startTimer();
    } catch (e) {
      _showErrorDialog('데이터 로딩 중 오류가 발생했습니다: $e');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _countdown = 30;
      _showQr = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          _showQr = false;
        });
      }
    });
  }

  String _simpleEncrypt(String input) {
    String result = '';
    for (int i = 0; i < input.length; i++) {
      if (input[i] == '-') {
        // 하이픈은 결과에 포함하지 않음
      } else if (input[i].contains(RegExp(r'[0-9]'))) {
        int digit = int.parse(input[i]);
        result += ((digit + 3) % 10).toString();
      } else {
        result += input[i];
      }
    }
    return result;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('확인'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('조이페이', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade800, Colors.black87],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _buildQrContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildQrContent() {
    if (!_showQr) {
      return GestureDetector(
        onTap: _loadAccountDataAndGenerateQr,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.tealAccent, Colors.blueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Text(
            'QR결제',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    if (_encryptedAccountNumber == null) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$_countdown 초 남음',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(blurRadius: 10.0, color: Colors.black54)],
          ),
        ),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                spreadRadius: 5,
                blurRadius: 15,
              ),
            ],
          ),
          child: QrImageView(
            data: _encryptedAccountNumber!,
            version: QrVersions.auto,
            size: 220.0,
          ),
        ),
        const SizedBox(height: 30),
        if (_balance != null)
          Text(
            '잔액: ${NumberFormat('#,###').format(_balance)}원',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
      ],
    );
  }
}
