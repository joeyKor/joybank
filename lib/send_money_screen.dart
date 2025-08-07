import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'currency_input_formatter.dart'; // 통화 포맷터 임포트

class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({super.key});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _recipientAccountController = TextEditingController();
  final TextEditingController _recipientNameDisplayController = TextEditingController(); // 예금주 표시용
  final FocusNode _amountFocusNode = FocusNode();
  String? _userId;
  double _currentBalance = 0.0;
  bool _isAccountValidated = false;
  String? _validatedRecipientUserId; // 유효성 검사된 받는 사람의 userId
  String _selectedBank = '국민은행'; // 기본 은행 설정

  final List<String> _banks = [
    '국민은행', '신한은행', '우리은행', '하나은행', '농협은행', '조이뱅크'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    if (_userId != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_userId).collection('accounts').doc('main').get();
      if (userDoc.exists) {
        setState(() {
          _currentBalance = (userDoc.data()?['balance'] ?? 0).toDouble();
        });
      }
    }
  }

  Future<void> _validateAccount() async {
    if (_selectedBank != '조이뱅크') {
      _showSnackBar('조이뱅크 계좌만 송금 가능합니다.');
      setState(() {
        _isAccountValidated = false;
        _recipientNameDisplayController.clear();
        _validatedRecipientUserId = null;
      });
      return;
    }

    final cleanedInputAccountNumber = _recipientAccountController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanedInputAccountNumber.isEmpty) {
      _showSnackBar('계좌번호를 입력해주세요.');
      return;
    }

    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      String? foundRecipientName;
      String? foundRecipientUserId;

      for (var userDoc in usersSnapshot.docs) {
        final accountsCollection = userDoc.reference.collection('accounts');
        final mainAccountDoc = await accountsCollection.doc('main').get();

        if (mainAccountDoc.exists) {
          final storedAccountNumber = mainAccountDoc.data()?['accountNumber'] as String?;
          if (storedAccountNumber != null) {
            final cleanedStoredAccountNumber = storedAccountNumber.replaceAll(RegExp(r'[^0-9]'), '');
            if (cleanedStoredAccountNumber == cleanedInputAccountNumber) {
              foundRecipientName = userDoc.data()?['name'] ?? '이름 없음';
              foundRecipientUserId = userDoc.id;
              break;
            }
          }
        }
      }

      if (foundRecipientName != null && foundRecipientUserId != null) {
        setState(() {
          _recipientNameDisplayController.text = foundRecipientName!;
          _isAccountValidated = true;
          _validatedRecipientUserId = foundRecipientUserId;
        });
        _showSnackBar('계좌가 확인되었습니다: $foundRecipientName', isError: false);
      } else {
        setState(() {
          _isAccountValidated = false;
          _recipientNameDisplayController.clear();
          _validatedRecipientUserId = null;
        });
        _showSnackBar('유효하지 않은 계좌번호입니다.');
      }
    } catch (e) {
      setState(() {
        _isAccountValidated = false;
        _recipientNameDisplayController.clear();
        _validatedRecipientUserId = null;
      });
      _showSnackBar('계좌 확인 중 오류가 발생했습니다: $e');
    }
  }

  void _sendMoney() async {
    if (_amountController.text.isEmpty || !_isAccountValidated || _validatedRecipientUserId == null) {
      _showSnackBar('금액을 입력하고 계좌 유효성 검사를 완료해주세요.');
      return;
    }

    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      _showSnackBar('유효한 금액을 입력해주세요.');
      return;
    }

    if (amount > _currentBalance) {
      _showSnackBar('잔액이 부족합니다.');
      return;
    }

    // 실제 송금 로직 (Firestore 업데이트)
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // 1. 내 계좌에서 금액 차감
      final myAccountRef = firestore.collection('users').doc(_userId).collection('accounts').doc('main');
      batch.update(myAccountRef, {'balance': FieldValue.increment(-amount)});

      // 2. 거래 내역 추가 (내 계좌)
      batch.set(firestore.collection('users').doc(_userId).collection('transactions').doc(), {
        'type': '송금',
        'amount': amount,
        'timestamp': Timestamp.now(),
        'description': '${_recipientNameDisplayController.text}님께 송금',
        'is_deposit': false,
        'balance_after': _currentBalance - amount,
      });

      // 3. 받는 사람 계좌에 금액 추가
      final recipientAccountRef = firestore.collection('users').doc(_validatedRecipientUserId).collection('accounts').doc('main');
      batch.update(recipientAccountRef, {'balance': FieldValue.increment(amount)});

      // 4. 거래 내역 추가 (받는 사람 계좌)
      // TODO: 내 이름 가져오는 로직 필요 (현재는 _userId 사용)
      batch.set(firestore.collection('users').doc(_validatedRecipientUserId).collection('transactions').doc(), {
        'type': '입금',
        'amount': amount,
        'timestamp': Timestamp.now(),
        'description': '$_userId님으로부터 입금', // TODO: 실제 내 이름으로 변경
        'is_deposit': true,
        'balance_after': FieldValue.increment(amount),
      });

      await batch.commit();
      _showSnackBar('송금이 완료되었습니다!', isError: false);
      Navigator.pop(context); // 송금 완료 후 이전 화면으로 돌아가기
    } catch (e) {
      _showSnackBar('송금 중 오류가 발생했습니다: $e');
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _recipientAccountController.dispose();
    _recipientNameDisplayController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('송금하기'),
        backgroundColor: Theme.of(context).primaryColor, // 앱 테마 색상 사용
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('내 계좌 정보'),
            _buildBalanceDisplay(),
            const SizedBox(height: 30),
            _buildSectionTitle('받는 사람 정보'),
            _buildBankSelection(), // 은행 선택 필드 추가
            const SizedBox(height: 15),
            _buildAccountInput(), // 계좌번호 입력 필드와 돋보기 아이콘
            if (_isAccountValidated) ...[
              const SizedBox(height: 15),
              _buildTextField(
                controller: _recipientNameDisplayController,
                labelText: '예금주',
                hintText: '예금주 이름',
                icon: Icons.person,
                readOnly: true, // 읽기 전용
              ),
            ],
            const SizedBox(height: 30),
            _buildSectionTitle('송금 금액'),
            _buildAmountInput(),
            const SizedBox(height: 40),
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor, // 앱 테마 색상 사용
        ),
      ),
    );
  }

  Widget _buildBalanceDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).primaryColor),
      ),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('accounts')
            .doc('main')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('계좌 정보 없음'));
          }
          final accountData = snapshot.data!.data() as Map<String, dynamic>;
          final balance = accountData['balance'] ?? 0;
          final accountNumber = accountData['accountNumber'] ?? 'N/A';

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                accountNumber,
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${NumberFormat('#,###').format(balance)}원',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon, // suffixIcon 추가
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor), // 앱 테마 색상 사용
        suffixIcon: suffixIcon, // suffixIcon 적용
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).primaryColor), // 앱 테마 색상 사용
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2), // 앱 테마 색상 사용
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.5)), // 앱 테마 색상 사용
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildBankSelection() {
    return _buildTextField(
      controller: TextEditingController(text: _selectedBank), // 선택된 은행 표시
      labelText: '은행 선택',
      hintText: '은행을 선택해주세요',
      icon: Icons.account_balance,
      readOnly: true,
      onTap: _showBankSelectionDialog,
      suffixIcon: Icon(Icons.arrow_drop_down, color: Theme.of(context).primaryColor),
    );
  }

  void _showBankSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('은행 선택'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _banks.length,
              itemBuilder: (BuildContext context, int index) {
                return ListTile(
                  title: Text(_banks[index]),
                  onTap: () {
                    setState(() {
                      _selectedBank = _banks[index];
                      _isAccountValidated = false; // 은행 변경 시 계좌 유효성 초기화
                      _recipientAccountController.clear();
                      _recipientNameDisplayController.clear();
                      _validatedRecipientUserId = null;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccountInput() {
    return _buildTextField(
      controller: _recipientAccountController,
      labelText: '계좌번호',
      hintText: '계좌번호를 입력해주세요',
      icon: Icons.credit_card,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      suffixIcon: IconButton(
        icon: Icon(Icons.search, color: Theme.of(context).primaryColor), // 앱 테마 색상 사용
        onPressed: _validateAccount,
      ),
    );
  }

  Widget _buildAmountInput() {
    return TextField(
      controller: _amountController,
      focusNode: _amountFocusNode,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        CurrencyInputFormatter(), // 통화 포맷터 적용
      ],
      textAlign: TextAlign.end,
      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor), // 앱 테마 색상 사용
      decoration: InputDecoration(
        hintText: '0원',
        hintStyle: TextStyle(fontSize: 32, color: Colors.grey[400]),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 15.0, top: 5.0),
          child: Text(
            '₩',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor), // 앱 테마 색상 사용
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).primaryColor), // 앱 테마 색상 사용
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2), // 앱 테마 색상 사용
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.5)), // 앱 테마 색상 사용
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      onTap: () {
        // 금액 입력 필드 탭 시 전체 선택
        _amountController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _amountController.text.length,
        );
      },
    );
  }

  Widget _buildSendButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _sendMoney,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor, // 앱 테마 색상 사용
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 5,
        ),
        child: const Text(
          '송금하기',
          style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
