import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:joybank/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this line

class TransactionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final String transactionId;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    required this.transactionId,
  });

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late Map<String, dynamic> _transactionData;
  bool _isEditingMemo = false;
  late TextEditingController _memoController;

  @override
  void initState() {
    super.initState();
    _transactionData = Map.from(widget.transaction);
    _memoController = TextEditingController(text: _transactionData['memo']);
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  void _toggleMemoEdit() async {
    if (_isEditingMemo) {
      // Save the memo to Firebase
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId != null) {
        await FirebaseService.updateTransactionMemo(
          userId,
          widget.transactionId,
          _memoController.text,
        );
      }
      _transactionData['memo'] = _memoController.text;
    }
    setState(() {
      _isEditingMemo = !_isEditingMemo;
    });
  }

  @override
  Widget build(BuildContext context) {
    final amount = _transactionData['amount'] as int;
    final isDeposit = amount > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('거래 상세 정보')),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDeposit
                        ? '${_transactionData['senderName'] ?? '알 수 없음'}'
                        : '${_transactionData['recipientName'] ?? '알 수 없음'}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${NumberFormat('#,###').format(amount)}원',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDeposit ? Colors.blue : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildMemoSection(),
                  const Spacer(),
                  _buildDetailInfoSection(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('확인', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  Widget _buildMemoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '메모',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: _toggleMemoEdit,
              child: Text(_isEditingMemo ? '저장' : '수정'),
            ),
          ],
        ),
        _isEditingMemo
            ? TextField(
              controller: _memoController,
              maxLength: 20,
              style: const TextStyle(color: Colors.grey), // Gray while editing
              decoration: const InputDecoration(
                hintText: '메모를 입력하세요 (최대 20자)',
                counterText: '', // Hide the counter
              ),
            )
            : Text(
              _transactionData['memo'] != null &&
                      _transactionData['memo'].isNotEmpty
                  ? _transactionData['memo']
                  : '메모 없음',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
              ), // Black when saved
            ),
      ],
    );
  }

  Widget _buildDetailInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '거래 정보',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 24),
          _buildInfoRow(
            '거래 일시',
            DateFormat('yyyy.MM.dd HH:mm').format(
              (_transactionData['timestamp'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
            ),
          ),
          _buildInfoRow('거래 내용', _transactionData['description'] ?? '내용 없음'),
          _buildInfoRow(
            '거래 금액',
            '${NumberFormat('#,###').format(_transactionData['amount'] ?? 0)}원',
          ),
          _buildInfoRow(
            '거래 후 잔액',
            '${NumberFormat('#,###').format(_transactionData['balance_after'] ?? 0)}원',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
