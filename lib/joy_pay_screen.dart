
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
    final cleaned = input.replaceAll('-', '');
    return 'pay$cleaned';
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('알림', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('확인', style: TextStyle(color: Color(0xFF005BAC), fontWeight: FontWeight.bold)),
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE4F4ED),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF191F28), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '조이페이 결제',
          style: TextStyle(
            color: Color(0xFF191F28),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 24),
            tooltip: '결제 코드 새로고침',
            onPressed: _startTimer,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // 상단 은은한 민트 그라데이션 배경
          Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE4F4ED),
                  Color(0xFFF1F8F5),
                  Color(0xFFF8FAFC),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: _buildQrContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrContent() {
    // 1. 결제 상태 화면 (processing, success, failed)
    if (_paymentState != null) {
      final status = _paymentState!['status'];
      final amount = _paymentState!['amount'] ?? 0;
      final storeName = _paymentState!['storeName'] ?? '';

      if (status == 'processing') {
        return _buildProcessingCard(storeName, amount);
      } else if (status == 'success') {
        final balanceAfter = _paymentState!['balanceAfter'] ?? 0;
        return _buildSuccessCard(storeName, amount, balanceAfter);
      } else if (status == 'failed') {
        final message = _paymentState!['message'] ?? '결제 중 오류가 발생했습니다.';
        return _buildFailedCard(message);
      }
    }

    // 2. 만료된 경우 (다시 생성 버튼)
    if (!_showQr) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer_off_rounded, size: 32, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            const Text(
              '인증 시간이 만료되었습니다',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF191F28),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '안전한 결제를 위해 새로운 결제 코드를 생성해 주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF8B95A1), height: 1.4),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _startTimer,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('결제 코드 다시 받기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF005BAC),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 3. 로딩 상태
    if (_encryptedAccountNumber == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF005BAC)));
    }

    // 4. 정상 QR 결제 카드
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 상단: 출금 계좌 정보 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF005BAC),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'JB',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '조이 스마트 입출금통장',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF191F28),
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (_balance != null)
                        Text(
                          '잔액 ${NumberFormat('#,###').format(_balance)}원',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF8B95A1),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5EF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '결제대기',
                    style: TextStyle(
                      color: Color(0xFF00A86B),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 24),
          // 타이머 배지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF005BAC)),
                const SizedBox(width: 6),
                Text(
                  '$_countdown초 남음',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF005BAC),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // QR 코드 박스
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
            ),
            child: QrImageView(
              data: _encryptedAccountNumber!,
              version: QrVersions.auto,
              size: 200.0,
              gapless: false,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF191F28),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF191F28),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 안내 문구
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '매장 결제 단말기(바코드/QR 리더기)에 보여주세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF4E5968),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.shield_outlined, size: 14, color: Color(0xFF8B95A1)),
              SizedBox(width: 4),
              Text(
                '1회용 보안 코드로 안전하게 암호화됩니다',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8B95A1),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  // --- 결제 진행 중 카드 ---
  Widget _buildProcessingCard(String storeName, dynamic amount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: Color(0xFF005BAC),
              strokeWidth: 4,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            storeName.isNotEmpty ? storeName : '가맹점',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8B95A1),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '결제가 진행 중입니다',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF191F28),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${NumberFormat('#,###').format(amount)}원',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF005BAC),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '잠시만 기다려주세요...',
            style: TextStyle(fontSize: 13, color: Color(0xFF8B95A1)),
          ),
        ],
      ),
    );
  }

  // --- 결제 완료 카드 ---
  Widget _buildSuccessCard(String storeName, dynamic amount, dynamic balanceAfter) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF5EF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, size: 34, color: Color(0xFF00A86B)),
          ),
          const SizedBox(height: 20),
          const Text(
            '결제 완료',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF191F28),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${NumberFormat('#,###').format(amount)}원이 정상 결제되었습니다.',
            style: const TextStyle(fontSize: 14, color: Color(0xFF8B95A1)),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 18),
          _buildPaymentDetailRow('결제 가맹점', storeName.isNotEmpty ? storeName : '조이 가맹점'),
          const SizedBox(height: 12),
          _buildPaymentDetailRow('결제 금액', '${NumberFormat('#,###').format(amount)}원', isHighlight: true),
          const SizedBox(height: 12),
          _buildPaymentDetailRow('결제 후 잔액', '${NumberFormat('#,###').format(balanceAfter)}원'),
          const SizedBox(height: 12),
          _buildPaymentDetailRow('결제 일시', DateFormat('yyyy.MM.dd HH:mm').format(DateTime.now())),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _clearPaymentStateAndClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF005BAC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('확인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // --- 결제 실패 카드 ---
  Widget _buildFailedCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded, size: 34, color: Color(0xFFEF4444)),
          ),
          const SizedBox(height: 20),
          const Text(
            '결제 실패',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF191F28),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF8B95A1), height: 1.4),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _clearPaymentStateAndReset,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('다시 시도', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Color(0xFF8B95A1), fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 16 : 14,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
            color: isHighlight ? const Color(0xFF005BAC) : const Color(0xFF191F28),
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
    _startTimer();
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

