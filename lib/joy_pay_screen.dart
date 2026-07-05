
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
  StreamSubscription<DocumentSnapshot>? _accountSubscription;
  Map<String, dynamic>? _paymentState;

  @override
  void initState() {
    super.initState();
    _loadAccountDataAndGenerateQr();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _accountSubscription?.cancel();
    super.dispose();
  }

  void _loadAccountDataAndGenerateQr() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null) {
      _showErrorDialog('사용자 ID를 찾을 수 없습니다. 다시 로그인해주세요.');
      return;
    }

    await _clearPaymentStateInFirestore();

    _accountSubscription?.cancel();
    _accountSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('accounts')
        .doc('main')
        .snapshots()
        .listen((doc) {
      if (!doc.exists || doc.data() == null) {
        _showErrorDialog('계정 정보를 찾을 수 없습니다. 계정을 확인해주세요.');
        return;
      }

      final data = doc.data()!;
      final accountNumber = data['accountNumber'];
      final balance = (data['balance'] as num?)?.toInt();
      final paymentState = data['paymentState'] != null
          ? Map<String, dynamic>.from(data['paymentState'])
          : null;

      if (accountNumber == null) {
        _showErrorDialog('계좌 번호를 찾을 수 없습니다. 계정 설정을 확인해주세요.');
        return;
      }

      setState(() {
        _encryptedAccountNumber = _simpleEncrypt(accountNumber);
        _balance = balance;
        _paymentState = paymentState;
        
        if (paymentState != null) {
          _timer?.cancel();
          _showQr = false;
        } else {
          _showQr = true;
        }
      });

      if (paymentState == null) {
        if (_timer == null || !_timer!.isActive) {
          _startTimer();
        }
      }
    }, onError: (e) {
      _showErrorDialog('데이터 로딩 중 오류가 발생했습니다: $e');
    });
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
    // 하이픈을 제외한 계좌번호에 'pay' 접두사를 붙임
    final cleaned = input.replaceAll('-', '');
    return 'pay$cleaned';
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
    if (_paymentState != null) {
      final status = _paymentState!['status'];
      final amount = _paymentState!['amount'] ?? 0;
      final storeName = _paymentState!['storeName'] ?? '';
      
      if (status == 'processing') {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  color: Colors.tealAccent,
                  strokeWidth: 4,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                '$storeName에서 결제 중',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '${NumberFormat('#,###').format(amount)}원',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.tealAccent.shade200,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '잠시만 기다려주세요...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        );
      } else if (status == 'success') {
        final balanceAfter = _paymentState!['balanceAfter'] ?? 0;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.tealAccent),
              ),
              const SizedBox(height: 24),
              const Text(
                '결제 성공',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 16),
              _buildPaymentDetailRow('가맹점', storeName),
              const SizedBox(height: 12),
              _buildPaymentDetailRow('결제금액', '${NumberFormat('#,###').format(amount)}원', isHighlight: true),
              const SizedBox(height: 12),
              _buildPaymentDetailRow('남은 잔액', '${NumberFormat('#,###').format(balanceAfter)}원'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _clearPaymentStateAndClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      } else if (status == 'failed') {
        final message = _paymentState!['message'] ?? '결제 중 오류가 발생했습니다.';
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
              ),
              const SizedBox(height: 24),
              const Text(
                '결제 실패',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _clearPaymentStateAndReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '다시 시도',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

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

  Widget _buildPaymentDetailRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, color: Colors.white60),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            color: isHighlight ? Colors.tealAccent : Colors.white,
          ),
        ),
      ],
    );
  }

  void _clearPaymentStateAndClose() async {
    await _clearPaymentStateInFirestore();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _clearPaymentStateAndReset() async {
    await _clearPaymentStateInFirestore();
    if (mounted) {
      // The listener will automatically handle document update and restart the countdown
    }
  }

  Future<void> _clearPaymentStateInFirestore() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .doc('main')
          .update({
        'paymentState': FieldValue.delete(),
      });
    } catch (e) {
      print('Error clearing payment state: $e');
    }
  }
}
